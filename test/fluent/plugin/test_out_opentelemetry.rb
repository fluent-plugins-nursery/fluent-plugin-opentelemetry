# frozen_string_literal: true

require "helper"

require "fluent/plugin/out_opentelemetry"
require "fluent/test/driver/output"

require "webrick"
require "webrick/https"

class Fluent::Plugin::OpentelemetryOutputTest < Test::Unit::TestCase
  DEEPLY_NESTED_LOGS =
    begin
      body = { "stringValue" => "x" }
      40.times { body = { "arrayValue" => { "values" => [body] } } }
      JSON.generate({ "resourceLogs" => [{ "resource" => {}, "scopeLogs" => [{ "logRecords" => [{ "body" => body }] }] }] },
                    max_nesting: false)
    end

  def setup
    Fluent::Test.setup

    @port = unused_tcp_port
  end

  def create_driver(conf = config)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::OpentelemetryOutput).configure(conf)
  end

  def test_configure
    d = create_driver(%[
      <http>
        endpoint "http://127.0.0.1:#{@port}"
      </http>
      <buffer>
        @type file
        path /tmp
      </buffer>
    ])
    assert_equal "http://127.0.0.1:#{@port}", d.instance.http_config.endpoint
    assert_equal 8 * 1024 * 1024, d.instance.buffer.chunk_limit_size

    if defined?(GRPC)
      d = create_driver(%[
        <grpc>
          endpoint "127.0.0.1:#{@port}"
        </grpc>
      ])
      assert_equal "127.0.0.1:#{@port}", d.instance.grpc_config.endpoint
    else
      assert_raise(Fluent::ConfigError) do
        create_driver(%[
          <grpc>
            endpoint "127.0.0.1:#{@port}"
          </grpc>
        ])
      end
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(%[])
    end
  end

  data("unknown record type" => {
         record: { "type" => "opentelemetry_unknown", "message" => TestData::JSON::LOGS },
         expected_log: "unknown type=1 (\"opentelemetry_unknown\")"
       },
       "empty payload" => {
         record: { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS, "message" => "{}" },
         expected_log: "no resourceLogs=1"
       },
       "empty resource" => {
         record: { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_TRACES, "message" => '{"resourceSpans":[]}' },
         expected_log: "no resourceSpans=1"
       },
       "broken message" => {
         record: { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_METRICS, "message" => TestData::JSON::INVALID },
         expected_log: "broken message=1"
       },
       "deeply nested message" => {
         record: { "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS, "message" => DEEPLY_NESTED_LOGS },
         expected_log: "broken message=1 (nesting of"
       })
  def test_skip_invalid_record(data)
    d = create_driver(%[
      <http>
        endpoint "http://127.0.0.1:#{@port}"
      </http>
    ])
    d.run(default_tag: "opentelemetry.test", shutdown: false) do
      d.feed(data[:record])
    end

    logs = d.instance.log.out.logs.join
    assert_include(logs, data[:expected_log])
    assert_not_include(logs, "NoMethodError")
  ensure
    d.instance_shutdown
  end

  def test_aggregate_warning_for_skipped_records
    d = create_driver(%[
      <http>
        endpoint "http://127.0.0.1:#{@port}"
      </http>
    ])
    d.run(default_tag: "opentelemetry.test", shutdown: false) do
      100.times do
        d.feed({ "type" => Fluent::Plugin::Opentelemetry::RECORD_TYPE_LOGS, "message" => "{}" })
      end
      d.feed({ "type" => "opentelemetry_unknown", "message" => "{}" })
    end

    warnings = d.instance.log.out.logs.grep(/Skipped invalid records/)
    assert_equal(1, warnings.size)
    assert_include(warnings.first, "total: 101")
    assert_include(warnings.first, "no resourceLogs=100")
    assert_include(warnings.first, "unknown type=1")
  ensure
    d.instance_shutdown
  end

  def test_truncate_sample_in_aggregated_warning
    d = create_driver(%[
      <http>
        endpoint "http://127.0.0.1:#{@port}"
      </http>
    ])
    d.run(default_tag: "opentelemetry.test", shutdown: false) do
      10.times do |i|
        d.feed({ "type" => "#{i}#{'あ' * 10000}", "message" => "{}" })
      end
    end

    warnings = d.instance.log.out.logs.grep(/Skipped invalid records/)
    assert_equal(1, warnings.size)
    assert_include(warnings.first, "unknown type=10")
    assert_operator(warnings.first.bytesize, :<, 500)
  ensure
    d.instance_shutdown
  end
end
