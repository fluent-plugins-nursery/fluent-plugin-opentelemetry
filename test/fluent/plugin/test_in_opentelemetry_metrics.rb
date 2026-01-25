# frozen_string_literal: true

require "helper"

require "fluent/plugin/in_opentelemetry_metrics"
require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/request"
require "fluent/test/driver/input"

require "test_plugin_classes"

class Fluent::Plugin::OpentelemetryMetricsInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup

    # Enable mock_process_clock for freezing Fluent::EventTime
    Timecop.mock_process_clock = true
    Timecop.freeze(Time.parse("2025-01-01 00:00:00 UTC"))
    @event_time = Fluent::EventTime.now
  end

  setup do
    # check @type and type in one configuration
    conf = <<~CONFIG
      <source>
        @type test_in_gen
        @id test_in_gen
        num 10
      </source>
      <filter>
        @type test_filter
        @id test_filter
      </filter>
      <match **>
        @type relabel
        @id test_relabel
        @label @test
      </match>
      <label @test>
        <match **>
          @type test_out
          @id test_out
        </match>
      </label>
      <label @copy>
        <match **>
          @type copy
          <store>
            @type test_out
            @id copy_out_1
          </store>
          <store>
            @type test_out
            @id copy_out_2
          </store>
        </match>
      </label>
      <label @ERROR>
        <match>
          @type null
          @id null
        </match>
      </label>
    CONFIG

    root_agent = Fluent::RootAgent.new(log: $log) # rubocop:disable Style/GlobalVars
    stub(Fluent::Engine).root_agent { root_agent }
    configure_root_agent(root_agent, conf)
  end

  def teardown
    Timecop.mock_process_clock = false
    Timecop.return
  end

  def configure_root_agent(root_agent, conf_str)
    conf = Fluent::Config.parse(conf_str, "(test)", "(test_dir)", true)
    root_agent.configure(conf)
    root_agent
  end

  def create_driver(conf = config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::OpentelemetryMetricsInput).configure(conf)
  end

  def config
    <<~CONFIG
      tag opentelemetry.test
      emit_interval 1s
    CONFIG
  end

  def test_metrics_record_conforms_to_spec
    metrics = Fluent::Plugin::OpentelemetryMetricsInput::Metrics.new(metric_name_prefix: "fluentd.")

    # validate the metrics record
    assert_nothing_raised do
      # If record does not conform to OpenTelemetry Protocol, it raises Google::Protobuf::ParseError.
      # To validate strictly, it set ignore_unknown_fields to false.
      Fluent::Plugin::Opentelemetry::Request::Metrics.new(metrics.record, ignore_unknown_fields: false)
    end
  end

  def test_emit_metrics
    d = create_driver
    d.run(expect_records: 1)

    event = d.events.first
    assert_equal("opentelemetry.test", event[0])
    assert_equal(@event_time, event[1])
    assert_equal(Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS, event[2]["type"])
    assert_nothing_raised do
      JSON.parse(event[2]["message"])
    end
  end

  def test_metrics_name_prefix
    d = create_driver(config + "metric_name_prefix foobarbaz.")
    d.run(expect_records: 1)

    event = d.events.first
    record = JSON.parse(event[2]["message"])

    metrics = record["resourceMetrics"][0]["scopeMetrics"][0]["metrics"]
    assert_true(metrics.all? { |metric| metric["name"].start_with?("foobarbaz.") })
  end

  def test_metrics_name_separator
    d = create_driver
    d.run(expect_records: 1)

    event = d.events.first
    record = JSON.parse(event[2]["message"])

    metrics = record["resourceMetrics"][0]["scopeMetrics"][0]["metrics"]
    metrics.each do |metric|
      assert_true(metric["name"].match?(/\A[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)+\z/))
    end
  end
end
