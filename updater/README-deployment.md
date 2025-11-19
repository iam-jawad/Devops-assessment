# Auto-Deployment System for Robot App

This directory contains an automated deployment system that monitors the local Docker registry for new robot-app images and automatically deploys them with health checks and rollback capabilities.

## Files Overview

- **`auto-deploy.sh`** - Main deployment script with full automation logic
- **`deploy-helper.sh`** - User-friendly wrapper script with common commands
- **`deploy-config.conf`** - Configuration file for deployment settings
- **`test-deployment.sh`** - Test suite for validating the deployment system
- **`README-deployment.md`** - This documentation file

## Features

### ✅ Automated Deployment Pipeline
- Checks local registry for new robot-app tags
- Pulls new images automatically
- Updates docker-compose.yml configuration
- Deploys containers with zero-downtime strategy
- Performs comprehensive health checks
- Automatic rollback on failure

### ✅ Health Monitoring
- Container health status verification
- HTTP endpoint health checks
- Configurable timeout and retry logic
- Multi-container health validation

### ✅ Rollback Mechanism
- Automatic rollback on health check failures
- Backup and restore of docker-compose.yml
- Graceful failure handling
- Manual rollback capabilities

### ✅ Monitoring & Logging
- Colored console output with timestamps
- Comprehensive logging system
- Real-time status monitoring
- Cron job integration for automation

## Quick Start

### 1. Basic Usage

```bash
# Check for new tags (read-only)
./deploy-helper.sh check

# Run full deployment
./deploy-helper.sh deploy

# Force deployment regardless of tags
./deploy-helper.sh force

# Check current status
./deploy-helper.sh status
```

### 2. Advanced Usage

```bash
# Start continuous monitoring
./deploy-helper.sh monitor

# Set up automatic deployments (cron)
./deploy-helper.sh setup

# Manual rollback
./deploy-helper.sh rollback

# View deployment logs
./deploy-helper.sh logs
```

## Deployment Process Flow

```
1. Check Registry
   ├── Get current tag from docker-compose.yml
   ├── Query local registry for latest tag
   └── Compare tags for differences

2. Pre-deployment
   ├── Backup current docker-compose.yml
   ├── Pull new image from registry
   └── Update compose file with new image tag

3. Deployment
   ├── Stop current containers
   ├── Start containers with new image
   └── Wait for containers to initialize

4. Health Verification
   ├── Check container running status
   ├── Verify health check endpoints
   ├── Validate all robot services
   └── Monitor for configured timeout

5. Success/Failure Handling
   ├── Success: Clean up backups
   └── Failure: Rollback to previous version
```

## Configuration

### Environment Variables
The system can be configured via `deploy-config.conf`:

```bash
# Registry settings
REGISTRY_URL="localhost:5000"
IMAGE_NAME="robot-app"

# Health check settings
HEALTH_CHECK_TIMEOUT=120
HEALTH_CHECK_INTERVAL=10

# Container management
ROBOT_CONTAINERS=("robot-service-1" "robot-service-2" "robot-service-3")
```

### Health Check Endpoints
The script monitors these endpoints for each robot container:
- `http://localhost:5001/health` (robot-service-1)
- `http://localhost:5002/health` (robot-service-2) 
- `http://localhost:5003/health` (robot-service-3)

## Automation Setup

### Cron Job (Recommended)
Set up automatic deployments every 5 minutes:
```bash
./deploy-helper.sh setup
```

This adds a cron job that:
- Runs deployment checks every 5 minutes
- Only deploys if new tags are found
- Logs all activity to `/var/log/auto-deploy.log`

### Manual Cron Setup
```bash
# Edit crontab
crontab -e

# Add line for every 5 minutes
*/5 * * * * cd /path/to/project/updater && ./auto-deploy.sh >> /var/log/auto-deploy.log 2>&1
```

## Monitoring & Troubleshooting

### Real-time Monitoring
```bash
# Continuous status monitoring
./deploy-helper.sh monitor

# Watch deployment logs
./deploy-helper.sh logs
```

### Manual Operations
```bash
# Check container status
docker ps --filter "label=monitoring=robot"

# Check container health
docker inspect robot-service-1 | grep Health

# Manual health check
curl http://localhost:5001/health
curl http://localhost:5002/health  
curl http://localhost:5003/health
```

### Rollback Operations
```bash
# Automatic rollback (on health failure)
# - Happens automatically during failed deployments

# Manual rollback
./deploy-helper.sh rollback

# Manual restore from backup
cp docker-compose.yml.backup docker-compose.yml
docker-compose down && docker-compose up -d
```

## Exit Codes

The deployment script uses these exit codes:

- **0**: Success - deployment completed successfully
- **1**: Failure - deployment failed, rollback attempted
- **2**: Critical failure - rollback also failed, manual intervention required

## Security Considerations

### Network Security
- Local registry communication over HTTP (localhost)
- Container communication via Docker bridge network
- Health checks use localhost endpoints

### Access Control
- Script requires Docker daemon access
- Modify docker-compose.yml permissions
- Log file write permissions required

## Integration with CI/CD

### GitHub Actions Integration
The auto-deploy system works with the registry-sync container:

1. GitHub Actions pushes new images to registry
2. registry-sync pulls them to local registry  
3. auto-deploy.sh detects and deploys new tags
4. Health checks ensure successful deployment

### Manual Testing
```bash
# Build image with correct version
cd ../robot
docker build --build-arg APP_VERSION=1.2.3 -t localhost:5000/robot-app:1.2.3 .

# Push to local registry
docker push localhost:5000/robot-app:1.2.3

# Run deployment
cd ../updater
./deploy-helper.sh deploy
```

**Important**: The `APP_VERSION` should be baked into the image during CI build process using `--build-arg APP_VERSION=<tag>`. The docker-compose file should NOT override this with environment variables.

## Troubleshooting Guide

### Common Issues

#### Registry Connection Failed
```bash
# Check registry status
curl http://localhost:5000/v2/_catalog

# Restart registry if needed
docker-compose restart local-registry
```

#### Health Check Timeouts
```bash
# Increase timeout in config
HEALTH_CHECK_TIMEOUT=300

# Check container logs
docker logs robot-service-1
```

#### Rollback Failures
```bash
# Manual recovery
cp docker-compose.yml.backup docker-compose.yml
docker-compose down --remove-orphans
docker-compose up -d
```

#### Permission Issues
```bash
# Fix script permissions
chmod +x auto-deploy.sh deploy-helper.sh

# Fix log permissions
sudo touch /var/log/auto-deploy.log
sudo chown $USER:$USER /var/log/auto-deploy.log
```

## Best Practices

1. **Test First**: Always test deployments in a staging environment
2. **Monitor Logs**: Regularly check deployment logs for issues
3. **Backup Strategy**: Keep multiple backup versions of docker-compose.yml
4. **Health Checks**: Ensure all containers have proper health check endpoints
5. **Gradual Rollout**: Consider blue-green deployment for larger environments
6. **Monitoring**: Set up alerts for deployment failures
7. **Documentation**: Keep deployment procedures documented and updated

## Advanced Features

### Custom Health Checks
Modify the health check function for custom validation:
```bash
# Add custom checks in auto-deploy.sh
check_custom_endpoint() {
    # Add your custom health verification logic
}
```

### Notification Integration
Configure webhook notifications in `deploy-config.conf`:
```bash
ENABLE_NOTIFICATIONS=true
WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Multi-Environment Support
Extend for multiple environments:
```bash
# Use environment-specific compose files
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
```

## Support

For issues with the auto-deployment system:
1. Check the troubleshooting guide above
2. Review deployment logs: `./deploy-helper.sh logs`
3. Verify container health: `./deploy-helper.sh status`
4. Test registry connectivity: `curl http://localhost:5000/v2/_catalog`

Remember: The auto-deployment system is designed to be safe-first with automatic rollbacks, but always monitor deployments and have manual recovery procedures ready.