# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "fluent-plugin-opentelemetry"
  spec.version = "0.1.0"
  spec.authors = ["Shizuo Fujita"]
  spec.email = ["fujita@clear-code.com"]

  spec.summary = "Fluentd input/output plugin to forward OpenTelemetry Protocol data."
  spec.description = "Fluentd input/output plugin to forward OpenTelemetry Protocol data."
  spec.homepage = "https://github.com/fluent-plugins-nursery/fluent-plugin-opentelemetry"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fluent-plugins-nursery/fluent-plugin-opentelemetry"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[test/ .git .github gemfiles Gemfile example])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency("async-http", "~> 0.88")
  spec.add_dependency("excon", "~> 1.2")
  spec.add_dependency("fluentd", "~> 1.18")
  spec.add_dependency("google-protobuf", "~> 4.30")
end
