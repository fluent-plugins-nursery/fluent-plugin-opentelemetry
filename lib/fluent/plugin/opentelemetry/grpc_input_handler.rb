# frozen_string_literal: true

require "fluent/plugin/opentelemetry/response"
require "opentelemetry/proto/collector/logs/v1/logs_service_services_pb"
require "opentelemetry/proto/collector/metrics/v1/metrics_service_services_pb"
require "opentelemetry/proto/collector/trace/v1/trace_service_services_pb"

module Fluent::Plugin::Opentelemetry
  class GrpcInputHandler
    class ServiceHandler
      class Logs < Opentelemetry::Proto::Collector::Logs::V1::LogsService::Service
        def callback=(block)
          @callback = block
        end

        def export(req, _call)
          @callback.call(req)
        end
      end

      class Metrics < Opentelemetry::Proto::Collector::Metrics::V1::MetricsService::Service
        def callback=(block)
          @callback = block
        end

        def export(req, _call)
          @callback.call(req)
        end
      end

      class Traces < Opentelemetry::Proto::Collector::Trace::V1::TraceService::Service
        def callback=(block)
          @callback = block
        end

        def export(req, _call)
          @callback.call(req)
        end
      end
    end

    class ExceptionInterceptor < GRPC::ServerInterceptor
      def request_response(request:, call:, method:)
        # call actual service
        yield
      rescue StandardError => e
        puts "[#{method}] Error: #{e.message}"
        raise
      end
    end

    def initialize(grpc_config, logger)
      @grpc_config = grpc_config
      @logger = logger
    end

    def run(logs:, metrics:, traces:)
      server = GRPC::RpcServer.new(interceptors: [ExceptionInterceptor.new])
      server.add_http2_port("#{@grpc_config.bind}:#{@grpc_config.port}", :this_port_is_insecure)

      logs_handler = ServiceHandler::Logs.new
      logs_handler.callback = lambda { |request|
        logs.call(request.to_json)
        Fluent::Plugin::Opentelemetry::Response::Logs.build
      }
      server.handle(logs_handler)

      metrics_handler = ServiceHandler::Metrics.new
      metrics_handler.callback = lambda { |request|
        metrics.call(request.to_json)
        Fluent::Plugin::Opentelemetry::Response::Metrics.build
      }
      server.handle(metrics_handler)

      traces_handler = ServiceHandler::Traces.new
      traces_handler.callback = lambda { |request|
        traces.call(request.to_json)
        Fluent::Plugin::Opentelemetry::Response::Traces.build
      }
      server.handle(traces_handler)

      server.run_till_terminated
    end
  end
end
