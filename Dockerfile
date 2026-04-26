FROM golang:1.22-alpine3.20

RUN apk add --no-cache bash curl

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]