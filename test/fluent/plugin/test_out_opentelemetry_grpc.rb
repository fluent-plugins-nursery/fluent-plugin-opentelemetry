# frozen_string_literal: true

require "helper"

require "fluent/plugin/opentelemetry/response"
require "fluent/plugin/out_opentelemetry"
require "fluent/test/driver/output"

if defined?(GRPC)
  require "opentelemetry/proto/collector/logs/v1/logs_service_services_pb"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_services_pb"
  require "opentelemetry/proto/collector/trace/v1/trace_service_services_pb"

  class Fluent::Plugin::OpentelemetryOutputGrpcTest < Test::Unit::TestCase
    class LogService < Opentelemetry::Proto::Collector::Logs::V1::LogsService::Service
      attr_reader :received

      def export(req, _call)
        @received = req
        Fluent::Plugin::Opentelemetry::Response::Logs.build
      end
    end

    class MetricsService < Opentelemetry::Proto::Collector::Metrics::V1::MetricsService::Service
      attr_reader :received

      def export(req, _call)
        @received = req
        Fluent::Plugin::Opentelemetry::Response::Metrics.build
      end
    end

    class TraceService < Opentelemetry::Proto::Collector::Trace::V1::TraceService::Service
      attr_reader :received

      def export(req, _call)
        @received = req
        Fluent::Plugin::Opentelemetry::Response::Traces.build
      end
    end

    def run_grpc_server
      @grpc_server = GRPC::RpcServer.new
      @grpc_server.add_http2_port("127.0.0.1:#{@port}", :this_port_is_insecure)

      @log_service = LogService.new
      @grpc_server.handle(@log_service)

      @metrics_service = MetricsService.new
      @grpc_server.handle(@metrics_service)

      @trace_service = TraceService.new
      @grpc_server.handle(@trace_service)

      @grpc_server.run_till_terminated
    end

    def setup
      Fluent::Test.setup

      @port = unused_tcp_port

      @received_logs_record = nil
      @received_metrics_record = nil
      @received_traces_record = nil

      @@grpc_server_thread = Thread.new do
        run_grpc_server
      end
    end

    def teardown
      @grpc_server.stop
      @@grpc_server_thread.kill
      @@grpc_server_thread = nil
    end

    def create_driver(conf = config)
      Fluent::Test::Driver::Output.new(Fluent::Plugin::OpentelemetryOutput).configure(conf)
    end

    def config
      <<~"CONFIG"
        <grpc>
          endpoint "127.0.0.1:#{@port}"
        </grpc>
      CONFIG
    end

    def test_send_logs
      event = { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS, "message" => TestData::JSON::LOGS }

      d = create_driver
      d.run(default_tag: "opentelemetry.test") do
        d.feed(event)
      end

      assert_equal(TestData::JSON::LOGS, @log_service.received.to_json)
    end

    def test_send_metrics
      event = { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS, "message" => TestData::JSON::METRICS }

      d = create_driver
      d.run(default_tag: "opentelemetry.test") do
        d.feed(event)
      end

      assert_equal(TestData::JSON::METRICS, @metrics_service.received.to_json)
    end

    def test_send_traces
      event = { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES, "message" => TestData::JSON::TRACES }

      d = create_driver
      d.run(default_tag: "opentelemetry.test") do
        d.feed(event)
      end

      assert_equal(TestData::JSON::TRACES, @trace_service.received.to_json)
    end
  end
end
