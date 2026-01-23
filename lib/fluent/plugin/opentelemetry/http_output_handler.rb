# frozen_string_literal: true

require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/request"

require "excon"
require "google/protobuf"
require "stringio"
require "zlib"

class Fluent::Plugin::Opentelemetry::HttpOutputHandler
  def initialize(http_config, transport_config, logger)
    @http_config = http_config
    @transport_config = transport_config
    @logger = logger

    tls_settings = {}
    if transport_config.protocol == :tls
      tls_settings[:client_cert] = @transport_config.cert_path
      tls_settings[:client_key] = @transport_config.private_key_path
      tls_settings[:client_key_pass] = @transport_config.private_key_passphrase
      tls_settings[:ssl_min_version] = Fluent::Plugin::Opentelemetry::TLS_VERSIONS_MAP[@transport_config.min_version]
      tls_settings[:ssl_max_version] = Fluent::Plugin::Opentelemetry::TLS_VERSIONS_MAP[@transport_config.max_version]
    end

    timeout_settings = {
      read_timeout: http_config.read_timeout,
      write_timeout: http_config.write_timeout,
      connect_timeout: http_config.connect_timeout
    }

    Excon.defaults[:ssl_verify_peer] = false if @transport_config.insecure
    @connections = {
      Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS => Excon.new(http_logs_endpoint, proxy: @http_config.proxy, persistent: true, **tls_settings, **timeout_settings),
      Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS => Excon.new(http_metrics_endpoint, proxy: @http_config.proxy, persistent: true, **tls_settings, **timeout_settings),
      Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES => Excon.new(http_traces_endpoint, proxy: @http_config.proxy, persistent: true, **tls_settings, **timeout_settings)
    }
  end

  def export(record)
    uri, headers, body = get_post_data(record)
    response = @connections[record["type"]].post(body: body, headers: headers, idempotent: true)

    # Explicitly consume the response body to clear the socket buffer.
    # Without this, Excon retains the buffer, causing memory leaks and blocking persistent connections.
    response.body

    return if response.status >= 200 && response.status < 300

    if response.status == 400
      # The client MUST NOT retry the request when it receives HTTP 400 Bad Request response.
      raise Fluent::UnrecoverableError, "got unrecoverable error response from '#{uri}', response code is #{response.status}"
    end

    if @http_config.retryable_response_codes&.include?(response.status)
      raise Fluent::Plugin::OpentelemetryOutput::RetryableResponse, "got retryable error response from '#{uri}', response code is #{response.status}"
    end
    if @http_config.error_response_as_unrecoverable
      raise Fluent::UnrecoverableError, "got unrecoverable error response from '#{uri}', response code is #{response.status}"
    else
      @logger.error "got error response from '#{uri}', response code is #{response.status}"
    end
  end

  private

  def http_logs_endpoint
    "#{@http_config.endpoint}/v1/logs"
  end

  def http_metrics_endpoint
    "#{@http_config.endpoint}/v1/metrics"
  end

  def http_traces_endpoint
    "#{@http_config.endpoint}/v1/traces"
  end

  def get_post_data(record)
    msg = record["message"]

    begin
      case record["type"]
      when Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS
        uri = http_logs_endpoint
        body = Fluent::Plugin::Opentelemetry::Request::Logs.new(msg).body
      when Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS
        uri = http_metrics_endpoint
        body = Fluent::Plugin::Opentelemetry::Request::Metrics.new(msg).body
      when Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES
        uri = http_traces_endpoint
        body = Fluent::Plugin::Opentelemetry::Request::Traces.new(msg).body
      end
    rescue Google::Protobuf::ParseError => e
      # The message format does not comply with the OpenTelemetry protocol.
      raise ::Fluent::UnrecoverableError, e.message
    end

    headers = { Fluent::Plugin::Opentelemetry::CONTENT_TYPE => Fluent::Plugin::Opentelemetry::CONTENT_TYPE_PROTOBUF }
    if @http_config.compress == :gzip
      headers[Fluent::Plugin::Opentelemetry::CONTENT_ENCODING] = Fluent::Plugin::Opentelemetry::CONTENT_ENCODING_GZIP
      gz = Zlib::GzipWriter.new(StringIO.new)
      gz << body
      body = gz.close.string
    end

    [uri, headers, body]
  end
end
