# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fluent/plugin/opentelemetry/constant"
require "fluent/plugin/opentelemetry/request"
require "fluent/test"
require "fluent/test/helpers"

require "excon"
require "json"
require "stringio"
require "test-unit"
require "timecop"
require "zlib"

include Fluent::Test::Helpers

module TestData
  module JSON
    # trim white spaces
    METRICS = ::JSON.generate(::JSON.parse(File.read(File.join(__dir__, "./fluent/resources/data/metrics.json"))))
    TRACES = ::JSON.generate(::JSON.parse(File.read(File.join(__dir__, "./fluent/resources/data/traces.json"))))
    LOGS = ::JSON.generate(::JSON.parse(File.read(File.join(__dir__, "./fluent/resources/data/logs.json"))))

    INVALID = '{"resourceMetrics": "invalid"}'
  end

  module ProtocolBuffers
    METRICS = Fluent::Plugin::Opentelemetry::Request::Metrics.new(TestData::JSON::METRICS).body
    TRACES = Fluent::Plugin::Opentelemetry::Request::Traces.new(TestData::JSON::TRACES).body
    LOGS = Fluent::Plugin::Opentelemetry::Request::Logs.new(TestData::JSON::LOGS).body

    INVALID = "invalid"
  end
end

def unused_tcp_port(num = 1)
  ports = []
  sockets = []
  num.times do
    s = TCPServer.open(0)
    sockets << s
    ports << s.addr[1]
  end
  sockets.each(&:close)
  return ports.first if num == 1

  ports
end
