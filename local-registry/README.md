# Local Registry with GHCR Synchronization

This directory contains a containerized local registry setup that automatically synchronizes images from GitHub Container Registry (GHCR), verifies their signatures using cosign, and pulls them to a local registry.

## Components

### 1. Local Registry (`local-registry` service)
- Runs a standard Docker Registry v2 on port 5000
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
5. **Access**: Applications can pull any synced tag from `localhost:5000` instead of GHCR

## Configuration

The sync service monitors the following image and **all its tags**:
- Source: `ghcr.io/{repository}/robot-app:*` (all tags)
- Local: `localhost:5000/robot-app:*` (all synced tags)

## Environment Variables

- `GITHUB_REPOSITORY`: The GitHub repository (e.g., "jawad/devops-assessment")
- `GITHUB_TOKEN`: Optional token for private repositories
- `GITHUB_ACTOR`: GitHub username for authentication

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

##
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