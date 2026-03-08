# frozen_string_literal: true

require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/http_output_handler"
require "fluent/plugin/output"

require "json"

begin
  require "grpc"

  require "fluent/plugin/opentelemetry/grpc_output_handler"
rescue LoadError
end

module Fluent::Plugin
  class OpentelemetryOutput < Output
    class RetryableResponse < StandardError; end

    Fluent::Plugin.register_output("opentelemetry", self)

    helpers :server

    config_section :buffer do
      config_set_default :chunk_keys, ["tag"]
    end

    config_section :http, required: false, multi: false, init: false, param_name: :http_config do
      desc "The endpoint"
      config_param :endpoint, :string, default: "http://127.0.0.1:4318"
      desc "The proxy for HTTP request"
      config_param :proxy, :string, default: ENV["HTTP_PROXY"] || ENV["http_proxy"]

      desc "Raise UnrecoverableError when the response is non success, 4xx/5xx"
      config_param :error_response_as_unrecoverable, :bool, default: true
      desc "The list of retryable response code"
      config_param :retryable_response_codes, :array, value_type: :integer, default: [429, 502, 503, 504]

      desc "Compress request body"
      config_param :compress, :enum, list: %i[text gzip], default: :text

      desc "The read timeout in seconds"
      config_param :read_timeout, :integer, default: 60
      desc "The write timeout in seconds"
      config_param :write_timeout, :integer, default: 60
      desc "The connect timeout in seconds"
      config_param :connect_timeout, :integer, default: 60
    end

    config_section :grpc, required: false, multi: false, init: false, param_name: :grpc_config do
      desc "The endpoint"
      config_param :endpoint, :string, default: "127.0.0.1:4317"

      desc "Compress request body"
      config_param :compress, :enum, list: %i[text gzip], default: :text

      desc "The timeout in seconds"
      config_param :timeout, :integer, default: 60

      desc "The interval in seconds to send gRPC keepalive pings."
      config_param :keepalive_time, :integer, default: 30

      desc "The timeout in seconds to wait for a keepalive ping acknowledgement."
      config_param :keepalive_timeout, :integer, default: 10
    end

    config_section :transport, required: false, multi: false, init: false, param_name: :transport_config do
      config_argument :protocol, :enum, list: [:tls], default: nil
    end

    def configure(conf)
      super

      if @grpc_config && !defined?(GRPC)
        raise Fluent::ConfigError, "To use gRPC feature, please install grpc gem such as 'fluent-gem install grpc'."
      end

      unless [@http_config, @grpc_config].one?
        raise Fluent::ConfigError, "Please configure either <http> or <grpc> section."
      end

      @http_handler = Opentelemetry::HttpOutputHandler.new(@http_config, @transport_config, log) if @http_config
      @grpc_handler = Opentelemetry::GrpcOutputHandler.new(@grpc_config, @transport_config, log) if @grpc_config
    end

    def multi_workers_ready?
      true
    end

    def write(chunk)
      BatchProcessor.build_export_requests(chunk).each do |export_request|
        if @grpc_handler
          @grpc_handler.export(export_request)
        else
          @http_handler.export(export_request)
        end
      end
    end

    class BatchProcessor
      RESOURCE_KEY_MAP = {
        Opentelemetry::RECORD_TYPE_LOGS => "resourceLogs",
        Opentelemetry::RECORD_TYPE_METRICS => "resourceMetrics",
        Opentelemetry::RECORD_TYPE_TRACES => "resourceSpans"
      }.freeze

      def self.build_export_requests(chunk)
        requests = {
          Opentelemetry::RECORD_TYPE_LOGS => {},
          Opentelemetry::RECORD_TYPE_METRICS => {},
          Opentelemetry::RECORD_TYPE_TRACES => {}
        }

        chunk.each do |_, record| # rubocop:disable Style/HashEachMethods
          record_type = record["type"]
          resource_key = RESOURCE_KEY_MAP[record_type]
          record["message"] = JSON.parse(record["message"])
          resource_hash = record["message"][resource_key][0]["resource"].hash
          if requests[record_type][resource_hash].nil?
            requests[record_type][resource_hash] = record
          else
            requests[record_type][resource_hash]["message"][resource_key].concat(record["message"][resource_key])
          end
        end

        merged_records = requests.values.flat_map(&:values)
        merged_records.each do |record|
          record["message"] = record["message"].to_json
        end
        merged_records
      end
    end
  end
end
