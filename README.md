# DevOps Assessment Project

This project demonstrates a complete DevOps pipeline with automated deployment, monitoring, and container orchestration for a robot application system.

## Project Structure

```
├── docker-compose.infrastructure.yml  # Infrastructure services (Prometheus, Grafana, Registry)
├── docker-compose.robots.yml         # Robot application services
├── manage-services.sh                # Service management script
├── robot/                            # Robot application source code
│   ├── app.py                       # Flask application with metrics
│   ├── Dockerfile                   # Robot app container definition
│   ├── requirements.txt             # Python dependencies
│   └── templates/
│       └── index.html               # Web interface template
├── monitoring/                       # Monitoring stack configuration
│   ├── prometheus1.yml              # Primary Prometheus config
│   ├── prometheus2.yml              # Secondary Prometheus config
│   ├── README.md                   # Monitoring setup guide
│   └── grafana/                    # Grafana dashboards and config
│       ├── dashboards/
│       └── provisioning/
├── local-registry/                  # Docker registry setup
│   ├── Dockerfile                  # Registry sync container
│   ├── entrypoint.sh               # Registry initialization script
│   ├── sync-images.sh              # Image synchronization script
│   └── README.md                   # Registry setup guide
└── updater/                        # Auto-deployment system
    ├── auto-deploy.sh               # Main deployment automation script
    ├── deploy-helper.sh             # User-friendly deployment commands
    ├── test-deployment.sh           # Deployment system testing
    ├── deploy-config.conf           # Configuration settings
    └── README-deployment.md         # Detailed deployment guide
```

## Components

### 🤖 Robot Application
- **Location**: `robot/`
- **Description**: Flask-based web application with Prometheus metrics
- **Features**: Health checks, metrics export, containerized deployment
- **Ports**: 5001-5003 (for robot-service-1, robot-service-2, robot-service-3)

### 📊 Monitoring Stack
- **Location**: `monitoring/`
- **Components**: 
  - Prometheus (dual instance setup)
  - Grafana with pre-configured dashboards
- **Features**: Multi-target scraping, high availability, automated provisioning
- **Ports**: 9090 (Prometheus-1), 9091 (Prometheus-2), 3000 (Grafana)

### 🗂️ Local Registry
- **Location**: `local-registry/`
- **Description**: Private Docker registry with GitHub integration
- **Features**: Image synchronization, automated pulls from GitHub packages
- **Port**: 5000

### 🔄 Auto-Deployment System
- **Location**: `updater/`
- **Description**: Automated deployment pipeline with health checks and rollback
- **Features**: 
  - Registry monitoring for new images
  - Zero-downtime deployments
  - Health verification
  - Automatic rollback on failures
  - Continuous monitoring and logging

## Quick Start

### 1. Start the Complete System
```bash
# Start infrastructure services (persistent)
./manage-services.sh start-infra

# Start robot services  
./manage-services.sh start-robots

# Or start everything at once
./manage-services.sh start

# Check status
./manage-services.sh status
```

### 2. Access the Applications
- **Robot Services**: 
  - http://localhost:5001 (Robot 1)
  - http://localhost:5002 (Robot 2)  
  - http://localhost:5003 (Robot 3)
- **Monitoring**:
  - http://localhost:9090 (Prometheus 1)
  - http://localhost:9091 (Prometheus 2)
  - http://localhost:3000 (Grafana - admin/admin)
- **Registry**: http://localhost:5000

### 3. Test Auto-Deployment
```bash
# Navigate to updater directory
cd updater/

# Test the deployment system
./test-deployment.sh

# Check for updates
./deploy-helper.sh check

# Check system status
./deploy-helper.sh status
```

## System Features

### High Availability
- **Dual Prometheus Setup**: Primary and secondary Prometheus instances
- **Multi-Robot Deployment**: Three robot service instances with load distribution
- **Health Monitoring**: Comprehensive health checks for all components

### Automation
- **CI/CD Integration**: GitHub Actions → Local Registry → Auto Deployment
- **Health-Based Rollbacks**: Automatic rollback on deployment failures
- **Monitoring Integration**: Metrics collection and alerting capabilities

### Container Orchestration
- **Docker Compose**: Complete service orchestration
- **Volume Management**: Persistent data storage for monitoring and registry
- **Network Isolation**: Dedicated bridge network for service communication

## Development Workflow

### 1. Code Changes
1. Make changes to robot application code
2. Commit and push to GitHub repository
3. GitHub Actions builds and pushes new image
4. Registry-sync pulls new image to local registry
5. Auto-deployment system detects and deploys new version

### 2. Monitoring and Verification
1. Check Grafana dashboards for deployment metrics
2. Verify robot services health status
3. Monitor Prometheus for application metrics
4. Review deployment logs for any issues

### 3. Manual Operations
```bash
# Manual deployment
cd updater/
./deploy-helper.sh deploy

# Monitor system
./deploy-helper.sh monitor

# Manual rollback if needed
./deploy-helper.sh rollback
```

## Configuration

### Environment Variables
Key configuration can be set via environment variables:
- `GITHUB_REPOSITORY`: Repository for image synchronization
- `GITHUB_TOKEN`: Authentication for GitHub packages
- `APP_VERSION`: Robot application version

### Service Configuration
- **Prometheus**: Configure scraping targets in `monitoring/prometheus*.yml`
- **Grafana**: Modify dashboards in `monitoring/grafana/dashboards/`
- **Deployment**: Adjust settings in `updater/deploy-config.conf`
- **Infrastructure Services**: Managed via `docker-compose.infrastructure.yml`
- **Robot Services**: Managed via `docker-compose.robots.yml`

## Troubleshooting

### Common Issues
1. **Services not starting**: Check `./manage-services.sh status` and service logs
2. **Registry not accessible**: Verify port 5000 is available and infrastructure services are running
3. **Deployment failures**: Check `updater/` logs and health endpoints
4. **Monitoring gaps**: Verify Prometheus targets and Grafana data sources
5. **Network issues**: Ensure robot-network is created properly

### Health Checks
```bash
# Check all services
./manage-services.sh status

# Test individual service health
curl http://localhost:5001/health
curl http://localhost:5002/health  
curl http://localhost:5003/health

# Check registry
curl http://localhost:5000/v2/_catalog
```

## Documentation

- **Monitoring Setup**: See `monitoring/README.md`
- **Registry Configuration**: See `local-registry/README.md`
- **Auto-Deployment**: See `updater/README-deployment.md`

## Architecture Benefits

This setup provides:
- **Scalability**: Easy to add more robot instances
- **Reliability**: Health checks and automatic rollbacks
- **Observability**: Complete monitoring and logging stack  
- **Automation**: Hands-off deployment pipeline
- **Maintainability**: Clear separation of concerns and documentation

The system demonstrates modern DevOps practices including Infrastructure as Code, continuous deployment, monitoring, and automated recovery mechanisms.