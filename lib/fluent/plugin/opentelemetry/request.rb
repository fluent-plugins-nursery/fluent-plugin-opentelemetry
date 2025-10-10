# frozen_string_literal: true

require "fluent/plugin/opentelemetry/constant"
require "opentelemetry/proto/collector/logs/v1/logs_service_pb"
require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
require "opentelemetry/proto/collector/trace/v1/trace_service_pb"

require "google/protobuf"

class Fluent::Plugin::Opentelemetry::Request
  class Logs
    def initialize(body, ignore_unknown_fields: true)
      @request =
        if body.start_with?("{")
          Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode_json(body, ignore_unknown_fields: ignore_unknown_fields)
        else
          Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode(body)
        end
    end

    def body
      @request.to_proto
    end

    def record
      @request.to_json
    end
  end

  class Metrics
    def initialize(body, ignore_unknown_fields: true)
      @request =
        if body.start_with?("{")
          Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest.decode_json(body, ignore_unknown_fields: ignore_unknown_fields)
        else
          Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest.decode(body)
        end
    end

    def body
      @request.to_proto
    end

    def record
      @request.to_json
    end
  end

  class Traces
    def initialize(body, ignore_unknown_fields: true)
      @request =
        if body.start_with?("{")
          Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest.decode_json(body, ignore_unknown_fields: ignore_unknown_fields)
        else
          Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest.decode(body)
        end
    end

    def body
      @request.to_proto
    end

    def record
      @request.to_json
    end
  end
end
