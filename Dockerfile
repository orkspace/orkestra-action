FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        bash \
        ca-certificates \
        golang-go && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]