FROM 1.26.2-alpine3.22

# coreutils  → GNU sha256sum (supports --check; BusyBox only has -c)
# docker-cli → docker login for ork registry push
# curl bash  → download + run install.sh
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    coreutils \
    docker-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
