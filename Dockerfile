FROM ubuntu:22.04

# Install required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        bash \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Directory where artifacts will be written
WORKDIR /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
