#!/bin/bash

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting local registry image synchronizer..."

# Wait for Docker daemon to be ready
while ! docker info >/dev/null 2>&1; do
    log "Waiting for Docker daemon..."
    sleep 5
done

log "Docker daemon is ready"

# Wait for local registry to be available
log "Waiting for local registry to be available..."
while ! curl -f http://localhost:5003/v2/ >/dev/null 2>&1; do
    log "Local registry not ready, waiting..."
    sleep 10
done

log "Local registry is available"

# Initial sync
log "Performing initial image sync..."
/app/sync-images.sh || log "Initial sync completed - waiting for images to be available"

# Start periodic sync (every minute)
log "Starting periodic sync (every 60 seconds)..."
while true; do
    sleep 60
    log "Running periodic sync..."
    /app/sync-images.sh || log "Sync cycle completed - no new images found"
done