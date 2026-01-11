# frozen_string_literal: true

require "helper"

require "fluent/plugin/in_opentelemetry"
require "fluent/plugin/opentelemetry/response"
require "fluent/test/driver/input"

if defined?(GRPC)
  require "opentelemetry/proto/collector/logs/v1/logs_service_services_pb"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_services_pb"
  require "opentelemetry/proto/collector/trace/v1/trace_service_services_pb"

  class Fluent::Plugin::OpentelemetryInputGrpcTest < Test::Unit::TestCase
    class ServiceStub
      class Logs
        def initialize(host, creds, **kw)
          @stub = Opentelemetry::Proto::Collector::Logs::V1::LogsService::Stub.new(host, creds, **kw)
        end

        def export(json)
          message = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode_json(json)
          @stub.export(message)
        end
      end

      class Metrics
        def initialize(host, creds, **kw)
          @stub = Opentelemetry::Proto::Collector::Metrics::V1::MetricsService::Stub.new(host, creds, **kw)
        end

        def export(json)
          message = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest.decode_json(json)
          @stub.export(message)
        end
      end

      class Traces
        def initialize(host, creds, **kw)
          @stub = Opentelemetry::Proto::Collector::Trace::V1::TraceService::Stub.new(host, creds, **kw)
        end

        def export(json)
          message = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest.decode_json(json)
          @stub.export(message)
        end
      end
    end

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

    def config
      <<~"CONFIG"
        tag opentelemetry.test
        <grpc>
          bind 127.0.0.1
          port #{@port}
        </grpc>
      CONFIG
    end

    data("metrics" => {
           request_data: TestData::JSON::METRICS,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS,
           record_data: TestData::JSON::METRICS
         },
         "traces" => {
           request_data: TestData::JSON::TRACES,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES,
           record_data: TestData::JSON::TRACES
         },
         "logs" => {
           request_data: TestData::JSON::LOGS,
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS,
           record_data: TestData::JSON::LOGS
         },
         "metrics with empty request" => {
           request_data: "{}",
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS,
           record_data: "{}"
         },
         "traces with empty request" => {
           request_data: "{}",
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES,
           record_data: "{}"
         },
         "logs with empty request" => {
           request_data: "{}",
           record_type: Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS,
           record_data: "{}"
         })
    def test_receive(data)
      d = create_driver
      d.run(expect_records: 1) do
        post_grpc(data[:record_type], data[:request_data])
      end

      expected_events = [["opentelemetry.test", @event_time, { "type" => data[:record_type], "message" => data[:record_data] }]]
      assert_equal(expected_events, d.events)
    end

    def test_receive_compressed_data
      d = create_driver
      d.run(expect_records: 1) do
        post_grpc(Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS, TestData::JSON::METRICS, compress: true)
      end

      expected_events = [["opentelemetry.test", @event_time, { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS, "message" => TestData::JSON::METRICS }]]
      assert_equal(expected_events, d.events)
    end

    def post_grpc(type, json_data, compress: false)
      channel_args = compress ? GRPC::Core::CompressionOptions.new({ default_algorithm: :gzip }).to_channel_arg_hash : {}
      service =
        case type
        when Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS
          ServiceStub::Logs.new("127.0.0.1:#{@port}", :this_channel_is_insecure, channel_args: channel_args)
        when Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS
          ServiceStub::Metrics.new("127.0.0.1:#{@port}", :this_channel_is_insecure, channel_args: channel_args)
        when Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES
          ServiceStub::Traces.new("127.0.0.1:#{@port}", :this_channel_is_insecure, channel_args: channel_args)
        end

      service.export(json_data)
    end
  end
end
