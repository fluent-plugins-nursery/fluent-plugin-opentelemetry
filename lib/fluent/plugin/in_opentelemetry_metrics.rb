# frozen_string_literal: true

require "fluent/plugin/input"
require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/version"
require "fluent/plugin_helper/timer"
require "fluent/version"

require "get_process_mem"
require "json"
require "socket"

module Fluent::Plugin
  class OpentelemetryMetricsInput < Input
    Fluent::Plugin.register_input("opentelemetry_metrics", self)

    helpers :timer

    desc "Determine the rate to emit internal metrics as events."
    config_param :emit_interval, :time, default: 60

    desc "The tag of the event."
    config_param :tag, :string

    desc "The prefix of metric name."
    config_param :metric_name_prefix, :string, default: "fluentd_"

    def start
      super

      @metrics = Metrics.new(metric_name_prefix: @metric_name_prefix)
      timer_execute(:in_opentelemetry_metrics, @emit_interval) do
        router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_METRICS, "message" => @metrics.record })
      end
    end

    module Extension
      refine Time do
        def to_nano_sec
          (to_i * 1_000_000_000) + nsec
        end
      end
    end

    class Metrics
      using Extension

      def initialize(metric_name_prefix:)
        @start_time_unix_nano = Time.now.to_nano_sec
        @metric_name_prefix = metric_name_prefix.to_s
        @hostname = Socket.gethostname
        @monitor_info = MonitorInfo.new
        @memory = GetProcessMem.new
      end

      def record
        values.to_json
      end

      def values
        metrics_data
      end

      private

      def metrics_data
        {
          "resourceMetrics" => [
            {
              "resource" => {
                "attributes" => [
                  string_value_attribute("service.name", "fluentd"),
                  string_value_attribute("service.version", Fluent::VERSION),
                  string_value_attribute("host.name", @hostname),
                  string_value_attribute("process.runtime.name", "ruby"),
                  string_value_attribute("process.runtime.version", RUBY_VERSION),
                  int_value_attribute("process.pid", Process.pid)
                ]
              },
              "scopeMetrics" => scope_metrics
            }
          ]
        }
      end

      def scope_metrics
        [
          {
            "scope" => {
              "name" => "fluent-plugin-opentelemetry",
              "version" => Fluent::Plugin::Opentelemetry::VERSION
            },
            "metrics" => metrics
          }
        ]
      end

      def metrics
        time_nano_sec = Time.now.to_nano_sec
        metrics = []

        @monitor_info.plugins_info_all.each do |record|
          attributes = {
            plugin_id: record["plugin_id"],
            plugin: plugin_name(record["plugin_category"], record["type"]),
            plugin_category: record["plugin_category"],
            plugin_type: record["type"]
          }.map { |k, v| string_value_attribute(k, v) }

          record.each do |key, value|
            next unless value.is_a?(Numeric)

            metrics << {
              "name" => @metric_name_prefix + key.to_s,
              "unit" => "1",
              # TODO: "description"
              "gauge" => {
                "dataPoints" => [
                  {
                    "startTimeUnixNano" => @start_time_unix_nano,
                    "timeUnixNano" => time_nano_sec,
                    "asDouble" => value,
                    "attributes" => attributes
                  }
                ]
              }
            }
          end
        end
        metrics.concat(process_metrics(time_nano_sec))

        metrics
      end

      def process_metrics(time_nano_sec)
        [
          {
            "name" => @metric_name_prefix + "process_memory_usage",
            "unit" => "By",
            "gauge" => {
              "dataPoints" => [
                {
                  "startTimeUnixNano" => @start_time_unix_nano,
                  "timeUnixNano" => time_nano_sec,
                  "asInt" => @memory.bytes.to_i,
                  "attributes" => [
                    string_value_attribute("type", "resident"),
                    int_value_attribute("process.pid", Process.pid)
                  ]
                }
              ]
            }
          },
          {
            "name" => @metric_name_prefix + "process_cpu_time",
            "unit" => "s",
            "sum" => {
              "aggregationTemporality" => 2, # CUMULATIVE
              "isMonotonic" => true,
              "dataPoints" => [
                {
                  "startTimeUnixNano" => @start_time_unix_nano,
                  "timeUnixNano" => time_nano_sec,
                  "asDouble" => Process.times.utime.to_f,
                  "attributes" => [
                    string_value_attribute("state", "user"),
                    int_value_attribute("process.pid", Process.pid)
                  ]
                }
              ]
            }
          }
        ]
      end

      def plugin_name(category, type)
        prefix =
          case category
          when "input"
            "in"
          when "output"
            "out"
          else
            category
          end

        "#{prefix}_#{type}"
      end

      def string_value_attribute(key, value)
        {
          "key" => key.to_s,
          "value" => {
            "stringValue" => value.to_s
          }
        }
      end

      def int_value_attribute(key, value)
        {
          "key" => key.to_s,
          "value" => {
            "intValue" => value
          }
        }
      end
    end

    # Imported from Fluent::Plugin::MonitorAgentInput
    class MonitorInfo
      # They are deprecated but remain for compatibiscripts/pluginslity
      MONITOR_INFO = {
        "output_plugin" => -> { is_a?(::Fluent::Plugin::Output) },
        "buffer_queue_length" => lambda {
          throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
          @buffer.queue.size
        },
        "buffer_timekeys" => lambda {
          throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
          @buffer.timekeys
        },
        "buffer_total_queued_size" => lambda {
          throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
          @buffer.stage_size + @buffer.queue_size
        },
        "retry_count" => -> { respond_to?(:num_errors) ? num_errors : nil }
      }.freeze

      def all_plugins
        array = []

        # get all input plugins
        array.concat Fluent::Engine.root_agent.inputs

        # get all output plugins
        array.concat Fluent::Engine.root_agent.outputs

        # get all filter plugins
        array.concat Fluent::Engine.root_agent.filters

        Fluent::Engine.root_agent.labels.each_value do |l|
          # TODO: Add label name to outputs / filters for identifying plugins
          array.concat l.outputs
          array.concat l.filters
        end

        array
      end

      def plugin_category(pe)
        case pe
        when Fluent::Plugin::Input
          "input"
        when Fluent::Plugin::Output, Fluent::Plugin::MultiOutput, Fluent::Plugin::BareOutput
          "output"
        when Fluent::Plugin::Filter
          "filter"
        else
          "unknown"
        end
      end

      def plugins_info_all(opts = {})
        all_plugins.map do |pe|
          get_monitor_info(pe, opts)
        end
      end

      IGNORE_ATTRIBUTES = %i(@config_root_section @config @masked_config).freeze

      # get monitor info from the plugin `pe` and return a hash object
      def get_monitor_info(pe, opts = {})
        obj = {}

        # Common plugin information
        obj["plugin_id"] = pe.plugin_id
        obj["plugin_category"] = plugin_category(pe)
        obj["type"] = pe.config["@type"]
        obj["config"] = pe.config if opts[:with_config]

        # run MONITOR_INFO in plugins' instance context and store the info to obj
        MONITOR_INFO.each_pair do |key, code|
          catch(:skip) do
            obj[key] = pe.instance_exec(&code)
          end
        rescue NoMethodError => e
          unless @first_warn
            log.error "NoMethodError in monitoring plugins", key: key, plugin: pe.class, error: e
            log.error_backtrace
            @first_warn = true
          end
        rescue StandardError => e
          log.warn "unexpected error in monitoring plugins", key: key, plugin: pe.class, error: e
        end

        if pe.respond_to?(:statistics)
          obj.merge!(pe.statistics["output"] || {})
          obj.merge!(pe.statistics["filter"] || {})
          obj.merge!(pe.statistics["input"] || {})
        end

        obj["retry"] = get_retry_info(pe.retry) if opts[:with_retry] && pe.instance_variable_defined?(:@retry)

        # include all instance variables if :with_debug_info is set
        if opts[:with_debug_info]
          iv = {}
          pe.instance_eval do
            instance_variables.each do |sym|
              next if IGNORE_ATTRIBUTES.include?(sym)

              key = sym.to_s[1..] # removes first '@'
              iv[key] = instance_variable_get(sym)
            end
          end
          obj["instance_variables"] = iv
        elsif (ivars = opts[:ivars])
          iv = {}
          ivars.each do |name|
            iname = "@#{name}"
            iv[name] = pe.instance_variable_get(iname) if pe.instance_variable_defined?(iname)
          end
          obj["instance_variables"] = iv
        end

        obj
      end
    end
  end
end
