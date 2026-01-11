# frozen_string_literal: true

require "helper"

require "fluent/plugin/out_opentelemetry"
require "fluent/test/driver/output"

require "webrick"
require "webrick/https"

class Fluent::Plugin::OpentelemetryOutputTest < Test::Unit::TestCase
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
    ])
    assert_equal "http://127.0.0.1:#{@port}", d.instance.http_config.endpoint

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
end
