# frozen_string_literal: true

require "fluent/plugin/input"
require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/http_input_handler"
require "fluent/plugin_helper/http_server"
require "fluent/plugin_helper/thread"

begin
  require "grpc"

  require "fluent/plugin/opentelemetry/grpc_input_handler"
rescue LoadError
end

module Fluent::Plugin
  class OpentelemetryInput < Input
    Fluent::Plugin.register_input("opentelemetry", self)

    helpers :thread, :http_server

    desc "The tag of the event."
    config_param :tag, :string

    config_section :http, required: false, multi: false, init: false, param_name: :http_config do
      desc "The address to bind to."
      config_param :bind, :string, default: "0.0.0.0"
      desc "The port to listen to."
      config_param :port, :integer, default: 4318
    end

    config_section :grpc, required: false, multi: false, init: false, param_name: :grpc_config do
      desc "The address to bind to."
      config_param :bind, :string, default: "0.0.0.0"
      desc "The port to listen to."
      config_param :port, :integer, default: 4317
    end

    config_section :transport, required: false, multi: false, init: false, param_name: :transport_config do
      config_argument :protocol, :enum, list: [:tls], default: nil
    end

    def configure(conf)
      super

      if @grpc_config && !defined?(GRPC)
        raise Fluent::ConfigError, "To use gRPC feature, please install grpc gem such as 'fluent-gem install grpc'."
      end

      unless [@http_config, @grpc_config].any?
        raise Fluent::ConfigError, "Please configure either <http> or <grpc> section, or both."
      end
    end

    def start
      super

      if @http_config
        http_handler = Opentelemetry::HttpInputHandler.new
        http_server_create_http_server(:in_opentelemetry_http_server, addr: @http_config.bind, port: @http_config.port, logger: log) do |serv|
          serv.post("/v1/logs") do |req|
            http_handler.logs(req) { |record| router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_LOGS, "message" => record }) }
          end
          serv.post("/v1/metrics") do |req|
            http_handler.metrics(req) { |record| router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_METRICS, "message" => record }) }
          end
          serv.post("/v1/traces") do |req|
            http_handler.traces(req) { |record| router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_TRACES, "message" => record }) }
          end
        end
      end

      if @grpc_config
        thread_create(:in_opentelemetry_grpc_server) do
          grpc_handler = Opentelemetry::GrpcInputHandler.new(@grpc_config, log)
          grpc_handler.run(
            logs: lambda { |record|
              router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_LOGS, "message" => record })
            },
            metrics: lambda { |record|
              router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_METRICS, "message" => record })
            },
            traces: lambda { |record|
              router.emit(@tag, Fluent::EventTime.now, { "type" => Opentelemetry::RECORD_TYPE_TRACES, "message" => record })
            }
          )
        end
      end
    end
  end
end
