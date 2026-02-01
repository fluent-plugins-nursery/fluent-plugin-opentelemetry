## [Unreleased]

## [0.5.0] - 2026-02-01

Improvements:

- out_opentelemetry: add gRPC keep alive settings (#29)
- in_opentelemetry_metrics: add Fluentd CPU and memory usage metrics (#21)
- out_opentelemetry: reuse the connection in grpc (#19)
- out_opentelemetry: add timeout parameter in grpc (#18)
- out_opentelemetry: add compress parameter in grpc (#17)
- ProtocolBuffer: update OTLP v1.9.0

Fixes:

- out_opentelemetry: fix memory leak by explicitly consuming response body (#27)
- out_opentelemetry: Fix buffer handling to support buffered flush modes (#26)
- in_opentelemetry_metrics: add process id in CPU and memory usage
- in_opentelemetry: Ensure request body is closed to prevent socket leaks (#25)
- in_opentelemetry: fix "Errno::EMFILE: Too many open files" error by reusing connection (#23)
- in_opentelemetry: stop the grpc server explicitly
- http_output_handler: Fix HTTP response handling to accept all 2xx success status codes (#13)

Breaking Changes:

- in_opentelemetry_metrics: rename attribute key name with dot separation
- in_opentelemetry_metrics: rename metrics to use dot notation instead of underscores (#28)

## [0.4.0] - 2025-10-10

- in_opentelemetry_metrics: Add plugin to support fluentd metrics export (#10)

## [0.3.0] - 2025-07-23

- in_opentelemetry: add ${type} placeholder support in tag parameter (#8)
- in_opentelemetry: use String for record keys (#6)

## [0.2.0] - 2025-06-26

- Make gRPC sending and receiving optional (#4)
  - To use gRPC sending and receiving, you need to install `grpc` gem manually.

## [0.1.0] - 2025-03-31

- Initial release
