FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \
    docker-cli \
    curl \
    jq \
    bash \
    wget \
    && rm -rf /var/cache/apk/*

# Install cosign
RUN wget -O /usr/local/bin/cosign https://github.com/sigstore/cosign/releases/download/v2.4.0/cosign-linux-amd64 \
    && chmod +x /usr/local/bin/cosign

# Create directory for scripts
WORKDIR /app

# Copy the sync script
COPY sync-images.sh /app/sync-images.sh
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/sync-images.sh /app/entrypoint.sh

# Create directories for registry data and logs
RUN mkdir -p /var/lib/registry /var/log

ENTRYPOINT ["/app/entrypoint.sh"]