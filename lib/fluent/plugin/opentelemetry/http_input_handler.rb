# frozen_string_literal: true

require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/request"
require "fluent/plugin/opentelemetry/response"
require "google/protobuf"
require "zlib"

unless Fluent::PluginHelper::HttpServer::Request.method_defined?(:headers)
  # This API was introduced at fluentd v1.19.0.
  # Ref. https://github.com/fluent/fluentd/pull/4903
  # If we have supported v1.19.0+ only, we can remove this patch.
  module Fluent::PluginHelper::HttpServer
    module Extension
      refine Request do
        def headers
          @request.headers
        end
      end
    end
  end

  using Fluent::PluginHelper::HttpServer::Extension
end

class Fluent::Plugin::Opentelemetry::HttpInputHandler
  def logs(req, &block)
    common(req, Fluent::Plugin::Opentelemetry::Request::Logs, Fluent::Plugin::Opentelemetry::Response::Logs, &block)
  end

  def metrics(req, &block)
    common(req, Fluent::Plugin::Opentelemetry::Request::Metrics, Fluent::Plugin::Opentelemetry::Response::Metrics, &block)
  end

  def traces(req, &block)
    common(req, Fluent::Plugin::Opentelemetry::Request::Traces, Fluent::Plugin::Opentelemetry::Response::Traces, &block)
  end

  private

  def common(req, request_class, response_class)
    content_type = req.headers["content-type"]
    content_encoding = req.headers["content-encoding"]&.first
    return response_unsupported_media_type unless valid_content_type?(content_type)
    return response_bad_request(content_type) unless valid_content_encoding?(content_encoding)

    body = req.body
    body = Zlib::GzipReader.new(StringIO.new(body)).read if content_encoding == Fluent::Plugin::Opentelemetry::CONTENT_ENCODING_GZIP

    begin
      record = request_class.new(body).record
    rescue Google::Protobuf::ParseError
      # The format in request body does not comply with the OpenTelemetry protocol.
      return response_bad_request(content_type)
    end

    yield record

    res = response_class.new
    response(200, content_type, res.body(type: Fluent::Plugin::Opentelemetry::Response.type(content_type)))
  end

  def valid_content_type?(content_type)
    case content_type
    when Fluent::Plugin::Opentelemetry::CONTENT_TYPE_PROTOBUF, Fluent::Plugin::Opentelemetry::CONTENT_TYPE_JSON
      true
    else
      false
    end
  end

  def valid_content_encoding?(content_encoding)
    return true if content_encoding.nil?

    content_encoding == Fluent::Plugin::Opentelemetry::CONTENT_ENCODING_GZIP
  end

  def response(code, content_type, body)
    [code, { Fluent::Plugin::Opentelemetry::CONTENT_TYPE => content_type }, body]
  end

  def response_unsupported_media_type
    response(415, Fluent::Plugin::Opentelemetry::CONTENT_TYPE_PAIN, "415 unsupported media type, supported: [application/json, application/x-protobuf]")
  end

  def response_bad_request(content_type)
    response(400, content_type, "") # TODO: fix body message
  end
end
