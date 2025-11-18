# Local Registry with GHCR Synchronization

This directory contains a containerized local registry setup that automatically synchronizes images from GitHub Container Registry (GHCR), verifies their signatures using cosign, and pulls them to a local registry.

## Components

### 1. Local Registry (`local-registry` service)
- Runs a standard Docker Registry v2 on port 5003
- Stores images locally for fast access
- Provides a local mirror of signed images from GHCR

### 2. Registry Sync (`registry-sync` service)
- Monitors GHCR for new images every minute
- Automatically discovers and syncs ALL available tags
- Verifies image signatures using cosign before pulling
- Automatically syncs verified images to the local registry
- Provides logging of all sync activities

## How it Works

1. **Tag Discovery**: Every 60 seconds, the sync service queries GHCR API to discover all available tags
2. **Image Monitoring**: Checks each discovered tag for updates by comparing digests
3. **Signature Verification**: Before pulling any image, it verifies the cosign signature
4. **Local Caching**: Verified images are pulled and pushed to the local registry
5. **Access**: Applications can pull any synced tag from `localhost:5003` instead of GHCR

## Configuration

The sync service monitors the following image and **all its tags**:
- Source: `ghcr.io/{repository}/robot-app:*` (all tags)
- Local: `localhost:5003/robot-app:*` (all synced tags)

## Environment Variables

- `GITHUB_REPOSITORY`: The GitHub repository (e.g., "jawad/devops-assessment")
- `GITHUB_TOKEN`: Optional token for private repositories
- `GITHUB_ACTOR`: GitHub username for authentication

## Usage

### Starting the Services
```bash
docker-compose up -d local-registry registry-sync
```

### Viewing Logs
```bash
# Registry sync logs
docker logs -f registry-sync

# Local registry logs
docker logs -f local-registry
```

### Pulling Images from Local Registry
```bash
# Pull the latest image
docker pull localhost:5003/robot-app:latest

# Pull a specific version
docker pull localhost:5003/robot-app:1.0.0

# List available images in local registry
curl -X GET http://localhost:5003/v2/_catalog
```

### Checking Image Tags
```bash
# List all tags for robot-app
curl -X GET http://localhost:5003/v2/robot-app/tags/list

# Example response: {"name":"robot-app","tags":["latest","1.0.0","1.1.0","v2.0.0"]}
```

## Security Features

- **Signature Verification**: Only images with valid cosign signatures are pulled
- **Read-only Docker Socket**: The sync container has read-only access to Docker
- **Isolated Network**: All services run in an isolated Docker network

## Monitoring

The sync process logs all activities including:
- Image check attempts
- Signature verification results
- Pull/push operations
- Error conditions

Logs are available via `docker logs registry-sync` or in the container at `/var/log/image-sync.log`.

## Troubleshooting

### Common Issues

1. **Registry not accessible**: Ensure port 5003 is not blocked
2. **Signature verification fails**: Check that the image was properly signed with cosign
3. **Pull failures**: Verify network connectivity to GHCR and authentication if needed

### Manual Sync
To manually trigger a sync:
```bash
docker exec registry-sync /app/sync-images.sh
```

### Registry Health Check
```bash
curl -f http://localhost:5003/v2/
```

## File Structure

```
local-registry/
├── Dockerfile          # Container image definition
├── sync-images.sh      # Main sync script
├── entrypoint.sh       # Container startup script
└── README.md           # This documentation
```