# Fluent::Plugin::Otlp

[Fluentd](https://fluentd.org/) input/output plugin to forward [OpenTelemetry Protocol](https://github.com/open-telemetry/opentelemetry-proto) data.

## Installation

### RubyGems

```sh
gem install fluent-plugin-otlp
```

### Bundler

```ruby
gem "fluent-plugin-otlp"
```

And then execute:

```sh
$ bundle
```

## Configuration

### Input plugin

To receive data, this plugin requires `<http>` or `<grpc>` section, or both.

#### Root section

| parameter | type   | description          | default  |
|-----------|--------|----------------------|----------|
| tag       | string | The tag of the event | required |

#### `<http>` section

This requires to receive data via HTTP/HTTPS.

| parameter | type    | description            | default   |
|-----------|---------|------------------------|-----------|
| bind      | string  | The address to bind to | `0.0.0.0` |
| port      | integer | The port to listen to  | `4318`    |

#### `<grpc>` section

This requires to receive data via gRPC.

> [!WARNING]
> Now, gRPC feature status is experimental.

| parameter | type    | description            | default   |
|-----------|---------|------------------------|-----------|
| bind      | string  | The address to bind to | `0.0.0.0` |
| port      | integer | The port to listen to  | `4318`    |

* `<transport>` section

Refer [Config: Transport Section](https://docs.fluentd.org/configuration/transport-section)

#### Example

```
<source>
  @type otlp
  tag otlp

  <http>
    bind 0.0.0.0
    port 4318
  </http>

  <grpc>
    bind 0.0.0.0
    port 4317
  </grpc>
</source>
```

### Output plugin

To send data, this plugin requires `<http>` or `<grpc>` section.

#### `<http>` section

This requires to send data via HTTP/HTTPS.

| parameter                       | type    | description                                                    | default                 |
|---------------------------------|---------|----------------------------------------------------------------|-------------------------|
| endpoint                        | string  | The endpoint for HTTP/HTTPS request                            | `http://127.0.0.1:4318` |
| proxy                           | string  | The proxy for HTTP/HTTPS request                               | `nil`                   |
| error_response_as_unrecoverable | bool    | Raise UnrecoverableError when the response code is not SUCCESS | `true`                  |
| retryable_response_codes        | array   | The list of retryable response codes                           | `nil`                   |
| read_timeout                    | integer | The read timeout in seconds                                    | `60`                    |
| write_timeout                   | integer | The write timeout in seconds                                   | `60`                    |
| connect_timeout                 | integer | The connect timeout in seconds                                 | `60`                    |

| parameter | type   | description                               | available values | default |
|-----------|--------|-------------------------------------------|------------------|---------|
| compress  | enum   | The option to compress HTTP request body  | `text` / `gzip`  | `text`  |

#### `<grpc>` section

This requires to send data via gRPC.

> [!WARNING]
> Now, gRPC feature status is experimental.

| parameter                       | type    | description                                                    | default          |
|---------------------------------|---------|----------------------------------------------------------------|------------------|
| endpoint                        | string  | The endpoint for HTTP/HTTPS request                            | `127.0.0.1:4317` |

#### `<transport>` section

| parameter              | type    | description                                    | default |
|------------------------|---------|------------------------------------------------|---------|
| cert_path              | string  | Specifies the path of Certificate file         | `nil`   |
| private_key_path       | string  | Specifies the path of Private Key file         | `nil`   |
| private_key_passphrase | string  | Specifies the public CA private key passphrase | `nil`   |

| parameter   | type | description                                                 | available values               | default |
|-------------|------|-------------------------------------------------------------|--------------------------------|---------|
| min_version | enum | Specifies the lower bound of the supported SSL/TLS protocol | `TLS1_1` / `TLS1_2` / `TLS1_3` | `nil`   |
| max_version | enum | The endpoint for HTTP/HTTPS request                         | `TLS1_1` / `TLS1_2` / `TLS1_3` | `nil`   |

Refer [Config: Transport Section](https://docs.fluentd.org/configuration/transport-section)

#### `<buffer>` section

| parameter  | type   | description                                               | default |
|------------|--------|-----------------------------------------------------------|---------|
| chunk_keys | array  | Overwrites the default `chunk_keys` value in this plugin. | `tag`   |

Refer [Config: Buffer Section](https://docs.fluentd.org/configuration/buffer-section)

#### Example

```
<match otlp.**>
  @type otlp

  <http>
    endpoint "https://127.0.0.1:4318"
  </http>
</match>
```

## Copyright

* Copyright(c) 2025- Shizuo Fujita
* License
  * Apache License, Version 2.0

