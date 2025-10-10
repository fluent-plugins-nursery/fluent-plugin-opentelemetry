# Fluentd Observability Demo

This is demo based on [fluent-bit-observability-demo](https://github.com/fluent/fluent-bit-observability-demo)
for using Fluentd to export OpenTelemetry traces and metrics.

The telemetry data have been provided by js application in `app` directory.

* metrics.js: OpenTelemetry instrumented application that exports metrics to an endpoint (Fluentd) using the OpenTelemetry protocol
* tracing.js: OpenTelemetry instrumented application that exports trace data to an endpoint (Fluentd) using the OpenTelemetry protocol

### Structure

```mermaid
flowchart LR
    A[app/metrics.js] -->|app metric data / otlp| C[Fluentd]
    B[app/tracing.js] -->|app trace data / otlp| C[Fluentd]
    C[Fluentd] -->|app metric data / otlp <br> Fluentd metric data / otlp| D[Otel Collector]
    C[Fluentd] -->|app trace data / otlp| F[Jaeger]
    C[Fluentd] -->|sample log / Fluentd Forward Protocol| D[Otel Collector]
    D[Otel Collector] -->|app metric data <br> Fluentd metric data | E[Prometheus / Grafana]
    D[Otel Collector] -->|sample log| G[Elasticsearch / Kibana]
```

### Setup

1. Run `docker-compose up -d --build` to start the application

### Visualize metrics data

This demo uses Prometheus / Grafana to visualize the metrics data.

1. Go to [`localhost:3000`](http://localhost:3000) and login to Grafana using credentials admin, admin

2. Then, show `demo > OpenTelemetry` in [dashboard](http://localhost:3000/dashboards).

![dashboard](./assets/dashboard.png)


### Visualize trace data

This demo uses Jaeger to visualize the trace data.

1. Navigate to [`localhost:16686`](http://localhost:16686/), select the correct service and find traces.

![find-traces](./assets/find-traces.png)

![trace-data](./assets/trace-data.png)

### Visualize log data

This demo uses Elasticsearch / Kibana to visualize the trace data.

1. Go to [`http://localhost:5601/app/discover#/`](http://localhost:5601/app/discover#/), then click on `Create data view`.

![discover](./assets/discover.png)

2. Specify `logs-*` to Index pattern and click Save data view to Kibana.

![create data view](./assets/create_data_view.png)

3. Then, go to Discover tab to check the logs. As you can see, logs are properly collected into the Elasticsearch + Kibana.

![discover logs](./assets/discover_logs.png)
