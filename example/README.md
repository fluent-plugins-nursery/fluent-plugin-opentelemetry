# Fluentd Observability Demo

This is demo based on [fluent-bit-observability-demo](https://github.com/fluent/fluent-bit-observability-demo)
for using Fluentd to export OpenTelemetry traces and metrics.

The telemetry data have been provided by js application in `app` directory.

* metrics.js: OpenTelemetry instrumented application that exports metrics to an endpoint (Fluentd) using the otlp protocol
* tracing.js: OpenTelemetry instrumented application that exports trace data to an endpoint (Fluentd) using the otlp protocol

### Setup

1. Run `docker-compose up -d --build` to start the application

### Visualize metrics data

1. Go to [`localhost:3000`](http://localhost:3000) and login to Grafana using credentials admin, admin

2. Then, show `demo > Basic Service Trace` in [dashboard](http://localhost:3000/dashboards).

![dashboard](./assets/dashboard.png)


### Visualize trace data

1. Navigate to [`localhost:16686`](http://localhost:16686/), select the correct service and find traces.

![find-traces](./assets/find-traces.png)


![trace-data](./assets/trace-data.png)

