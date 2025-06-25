FROM fluent/fluentd:edge-debian

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    make \
    gcc \
    git
RUN gem install fluent-plugin-opentelemetry grpc
