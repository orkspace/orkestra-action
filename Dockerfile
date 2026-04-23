FROM ubuntu:22.04

# Install required tools
RUN apk add --no-cache curl bash ca-certificates

# Directory where artifacts will be written
WORKDIR /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default command
ENTRYPOINT ["/entrypoint.sh"]
