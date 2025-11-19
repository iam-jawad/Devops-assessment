# Robot Service

A simple Flask-based web service that simulates a robot with health monitoring and Prometheus metrics integration.

## Overview

This service provides a simple robot web interface with the following features:
- Web UI displaying robot information (ID, version, status)
- Health check endpoint for container orchestration
- Prometheus metrics for monitoring and observability
- Containerized deployment with Docker

## Features

### Web Interface
- **Main Page** (`/`): Displays robot details including ID, version, and status
- Clean, responsive HTML interface with robot information

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Main web interface showing robot details |
| `/health` | GET | Health check endpoint (returns JSON status) |
| `/metrics` | GET | Prometheus metrics in exposition format |

### Prometheus Metrics

The service exposes the following metrics for monitoring:

- `robot_info` - Robot information with labels (robot_id, version, status)
- `robot_health_status` - Robot health status (1=healthy, 0=unhealthy)
- `robot_requests_total` - Total HTTP requests counter with endpoint and robot_id labels
- `robot_version` - Robot version information with labels

## Configuration

### Environment Variables

- `ROBOT_ID` - Unique identifier for the robot instance (default: "1")
- `APP_VERSION` - Application version (default: "1.0.0")

### Docker Build Arguments

- `APP_VERSION` - Sets the application version during build time

## Getting Started

### Local Development

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set environment variables (optional):**
   ```bash
   export ROBOT_ID=1
   export APP_VERSION=1.0.0
   ```

3. **Run the application:**
   ```bash
   python app.py
   ```

4. **Access the service:**
   - Web Interface: http://localhost:5000
   - Health Check: http://localhost:5000/health
   - Metrics: http://localhost:5000/metrics

### Docker Deployment

1. **Build the Docker image:**
   ```bash
   docker build -t robot-app:latest .
   ```

2. **Run the container:**
   ```bash
   docker run -d -p 5000:5000 --name robot-service robot-app:latest
   ```

3. **Run with custom configuration:**
   ```bash
   docker run -d -p 5001:5000 \
     -e ROBOT_ID=2 \
     -e APP_VERSION=2.0.0 \
     --name robot-service-2 \
     robot-app:latest
   ```

## Dependencies

- **Flask 2.3.3** - Web framework
- **requests 2.31.0** - HTTP library
- **prometheus-client 0.18.0** - Prometheus metrics library

## Docker Image Details

- **Base Image**: python:3.11-slim
- **Security**: Runs as non-root user (appuser)
- **Health Check**: Built-in health check using curl
- **Port**: Exposes port 5000
- **System Dependencies**: Includes curl for health checks

## Health Monitoring

The service includes comprehensive health monitoring:

### Docker Health Check
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start Period**: 5 seconds
- **Retries**: 3
- **Command**: `curl -f http://localhost:5000/health`

### Application Health
The `/health` endpoint returns:
```json
{
  "status": "healthy"
}
```

## Monitoring Integration

This service is designed to work with:
- **Prometheus** - Metrics collection via `/metrics` endpoint
- **Grafana** - Visualization of collected metrics
- **Docker Health Checks** - Container-level health monitoring

## File Structure

```
robot/
├── app.py              # Main Flask application
├── Dockerfile          # Docker image configuration
├── requirements.txt    # Python dependencies
├── templates/
│   └── index.html     # Web interface template
└── README.md          # This file
```