# frozen_string_literal: true

require "helper"

require "fluent/plugin/in_opentelemetry"
require "fluent/test/driver/input"

class Fluent::Plugin::OpentelemetryInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup

    @port = unused_tcp_port

    # Enable mock_process_clock for freezing Fluent::EventTime
    Timecop.mock_process_clock = true
    Timecop.freeze(Time.parse("2025-01-01 00:00:00 UTC"))
    @event_time = Fluent::EventTime.now
  end

  def teardown
    Timecop.mock_process_clock = false
    Timecop.return
  end

  def create_driver(conf = config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::OpentelemetryInput).configure(conf)
  end

  def test_configure
    d = create_driver(%[
      tag opentelemetry.test
      <http>
        bind 127.0.0.1
        port #{@port}
      </http>
    ])
    assert_equal "opentelemetry.test", d.instance.tag
    assert_equal "127.0.0.1", d.instance.http_config.bind
    assert_equal @port, d.instance.http_config.port

    if defined?(GRPC)
      d = create_driver(%[
        tag opentelemetry.test
        <grpc>
          bind 127.0.0.1
          port #{@port}
        </grpc>
      ])
      assert_equal "127.0.0.1", d.instance.grpc_config.bind
      assert_equal @port, d.instance.grpc_config.port

      d = create_driver(%[
        tag opentelemetry.test
        <http>
          bind 127.0.0.1
          port #{@port}
        </http>
        <grpc>
          bind 127.0.0.1
          port #{@port}
        </grpc>
      ])
      assert_equal "127.0.0.1", d.instance.http_config.bind
      assert_equal @port, d.instance.http_config.port
      assert_equal "127.0.0.1", d.instance.grpc_config.bind
      assert_equal @port, d.instance.grpc_config.port
    else
      assert_raise(Fluent::ConfigError) do
        create_driver(%[
          tag opentelemetry.test
          <grpc>
            bind 127.0.0.1
            port #{@port}
          </grpc>
        ])
      end
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(%[
        tag opentelemetry.test
      ])
    end
  end

  sub_test_case "Placeholder" do
    def config
      <<~"CONFIG"
        tag opentelemetry.${type}
        <http>
          bind 127.0.0.1
          port #{@port}
        </http>
      CONFIG
    end

    data("metrics" => {
           request_path: "/v1/metrics",
           request_data: TestData::JSON::METRICS,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS,
           record_data: TestData::JSON::METRICS,
           expanded_tag: "opentelemetry.metrics"
         },
         "traces" => {
           request_path: "/v1/traces",
           request_data: TestData::JSON::TRACES,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES,
           record_data: TestData::JSON::TRACES,
           expanded_tag: "opentelemetry.traces"
         },
         "logs" => {
           request_path: "/v1/logs",
           request_data: TestData::JSON::LOGS,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS,
           record_data: TestData::JSON::LOGS,
           expanded_tag: "opentelemetry.logs"
         })
    def test_type_placeholder(data)
      d = create_driver
      res = d.run(expect_records: 1) do
        post_json(data[:request_path], data[:request_data])
      end

      expected_events = [[data[:expanded_tag], @event_time, { "type" => data[:record_type], "message" => data[:record_data] }]]
      assert_equal(200, res.status)
      assert_equal(expected_events, d.events)
    end
  end

  def post_json(path, json, headers: {}, options: {})
    headers = headers.merge({ "Content-Type" => "application/json" })
    post(path, json, headers: headers, options: options)
  end

  def post(path, body, endpoint: "http://127.0.0.1:#{@port}", headers: {}, options: {})
    connection = Excon.new("#{endpoint}#{path}", body: body, headers: headers, **options)
    connection.post
  end
end
