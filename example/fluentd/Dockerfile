FROM fluent/fluentd:edge-debian

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    make \
    gcc \
    git
RUN git clone https://github.com/fluent-plugins-nursery/fluent-plugin-opentelemetry.git && \
    cd fluent-plugin-opentelemetry && \
    gem build fluent-plugin-opentelemetry.gemspec && \
    gem install fluent-plugin-opentelemetry-*.gem
