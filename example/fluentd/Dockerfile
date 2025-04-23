FROM fluent/fluentd:edge-debian

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    make \
    gcc \
    git
RUN git clone https://github.com/fluent-plugins-nursery/fluent-plugin-otlp.git && \
    cd fluent-plugin-otlp && \
    gem build fluent-plugin-otlp.gemspec && \
    gem install fluent-plugin-otlp-*.gem
