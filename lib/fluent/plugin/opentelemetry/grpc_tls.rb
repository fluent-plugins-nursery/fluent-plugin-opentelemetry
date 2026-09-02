# frozen_string_literal: true

require "fluent/plugin/opentelemetry/constant"

require "openssl"

module Fluent::Plugin::Opentelemetry
  module GrpcTLS
    module_function

    def validate_server!(transport_config)
      return unless tls?(transport_config)

      if transport_config.cert_path.nil? || transport_config.private_key_path.nil?
        raise Fluent::ConfigError, "<transport tls> cert_path and private_key_path are required when <grpc> is used"
      end

      if transport_config.client_cert_auth && transport_config.ca_path.nil?
        raise Fluent::ConfigError, "<transport tls> client_cert_auth requires ca_path when <grpc> is used"
      end

      [transport_config.ca_path, transport_config.cert_path, transport_config.private_key_path].compact.each do |path|
        raise Fluent::ConfigError, "<transport tls> cannot read '#{path}'" unless File.readable?(path)
      end
    end

    def channel_credentials(transport_config)
      return :this_channel_is_insecure unless tls?(transport_config)

      GRPC::Core::ChannelCredentials.new(
        read_pem(transport_config.ca_path),
        read_private_key(transport_config),
        read_pem(transport_config.cert_path)
      )
    end

    def server_credentials(transport_config)
      return :this_port_is_insecure unless tls?(transport_config)

      GRPC::Core::ServerCredentials.new(
        read_pem(transport_config.ca_path),
        [{ private_key: read_private_key(transport_config), cert_chain: read_pem(transport_config.cert_path) }],
        transport_config.client_cert_auth
      )
    end

    def tls?(transport_config)
      transport_config.protocol == :tls
    end

    def read_pem(path)
      return nil unless path

      File.read(path)
    rescue SystemCallError, IOError => e
      raise Fluent::ConfigError, "<transport tls> failed to read '#{path}': #{e.message}"
    end

    def read_private_key(transport_config)
      pem = read_pem(transport_config.private_key_path)
      return nil unless pem

      OpenSSL::PKey.read(pem, transport_config.private_key_passphrase.to_s).to_pem
    rescue OpenSSL::PKey::PKeyError => e
      raise Fluent::ConfigError,
            "<transport tls> failed to load private_key_path '#{transport_config.private_key_path}': #{e.message}"
    end

    private_class_method :tls?, :read_pem, :read_private_key
  end
end
