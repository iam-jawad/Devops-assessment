import os
import subprocess
from flask import Flask, render_template, Response
from prometheus_client import Counter, Gauge, Info, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Prometheus metrics
robot_info = Gauge('robot_info', 'Robot information', ['robot_id', 'version', 'status'])
robot_health_status = Gauge('robot_health_status', 'Robot health status (1=healthy, 0=unhealthy)', ['robot_id'])
robot_requests_total = Counter('robot_requests_total', 'Total HTTP requests', ['endpoint', 'robot_id'])
robot_version = Gauge('robot_version', 'Robot version information', ['robot_id', 'version'])

def get_app_version():
    """Get version from Docker image label or fallback to default"""
    try:
        # Try to get version from Docker image label
        result = subprocess.run([
            'docker', 'inspect', '--format={{index .Config.Labels "version"}}', 
            os.environ.get('HOSTNAME', 'unknown')
        ], capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    
    # Fallback to environment variable or default
    return os.environ.get('APP_VERSION', '1.0.0')

def get_container_status():
    """Get container health status"""
    try:
        # Check if we're running in a container by looking for .dockerenv
        if os.path.exists('/.dockerenv'):
            # Simple health check - if we can respond, we're healthy
            return "Healthy"
        else:
            return "Running (not containerized)"
    except Exception:
        return "Unknown"

def update_metrics():
    """Update Prometheus metrics"""
    robot_id = os.environ.get('ROBOT_ID', '1')
    version = get_app_version()
    status = get_container_status()
    
    # Update metrics with labels
    robot_info.labels(robot_id=robot_id, version=version, status=status).set(1)
    robot_version.labels(robot_id=robot_id, version=version).set(1)
    
    # Health status as numeric (1=healthy, 0=unhealthy)
    health_value = 1 if status.lower() == "healthy" else 0
    robot_health_status.labels(robot_id=robot_id).set(health_value)

@app.route('/')
def index():
    """Main route to display robot details"""
    robot_id = os.environ.get('ROBOT_ID', '1')
    robot_requests_total.labels(endpoint='index', robot_id=robot_id).inc()
    
    robot_data = {
        'id': robot_id,
        'version': get_app_version(),
        'status': get_container_status()
    }
    
    update_metrics()
    return render_template('index.html', robot=robot_data)

@app.route('/health')
def health():
    """Health check endpoint"""
    robot_id = os.environ.get('ROBOT_ID', '1')
    robot_requests_total.labels(endpoint='health', robot_id=robot_id).inc()
    update_metrics()
    return {'status': 'healthy'}, 200

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    robot_id = os.environ.get('ROBOT_ID', '1')
    robot_requests_total.labels(endpoint='metrics', robot_id=robot_id).inc()
    update_metrics()
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == '__main__':
    # Run the application
    app.run(host='0.0.0.0', port=5000, debug=False)