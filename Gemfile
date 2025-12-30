# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in fluent-plugin-opentelemetry.gemspec
gemspec

unless ENV["CI"]
  gem "grpc"
  gem "grpc-tools"
end
gem "irb"
gem "rake"
gem "rr"
gem "test-unit"
gem "test-unit-rr"
gem "timecop"

gem "rubocop", "~> 1.75"
gem "rubocop-fluentd", "~> 0.2"
gem "rubocop-performance", "~> 1.25"
