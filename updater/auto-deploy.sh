#!/bin/bash

# Auto-deployment script for robot-app containers
# This script checks for new tags, deploys them, and rolls back on failure

set -e

# Configuration
REGISTRY_URL="localhost:5000"
IMAGE_NAME="robot-app"
COMPOSE_FILE="../docker-compose.robots.yml"
HEALTH_CHECK_TIMEOUT=120
HEALTH_CHECK_INTERVAL=10
BACKUP_COMPOSE_FILE="../docker-compose.robots.yml.backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Function to get current image tag from docker-compose.yml
get_current_tag() {
    if grep -q "image:" "$COMPOSE_FILE"; then
        # Extract tag from image field if exists
        grep -m1 "image:.*${REGISTRY_URL}/${IMAGE_NAME}" "$COMPOSE_FILE" | sed -n 's/.*://p' | tr -d ' '
    else
        # If no image field, assume we're using build context (return "build")
        echo "build"
    fi
}

# Function to get latest tag from local registry
get_latest_tag() {
    # Get all tags from registry API
    if ! curl -s "http://${REGISTRY_URL}/v2/${IMAGE_NAME}/tags/list" > /tmp/tags_response.json; then
        log_error "Failed to connect to registry"
        return 1
    fi
    
    if ! python3 -c "
import json
try:
    with open('/tmp/tags_response.json', 'r') as f:
        data = json.load(f)
    tags = data.get('tags', [])
    if not tags:
        print('No tags found')
        exit(1)
    
    # Sort tags by version (assuming semver or timestamp format)
    # Filter out 'latest' tag and sort numerically if possible
    numeric_tags = []
    other_tags = []
    
    for tag in tags:
        if tag == 'latest':
            continue
        try:
            # Try to parse as float for simple numeric comparison
            float(tag.replace('.', '').replace('v', ''))
            numeric_tags.append(tag)
        except:
            other_tags.append(tag)
    
    if numeric_tags:
        # Sort numeric tags
        sorted_tags = sorted(numeric_tags, key=lambda x: [int(i) for i in x.replace('v', '').split('.') if i.isdigit()], reverse=True)
        print(sorted_tags[0])
    elif other_tags:
        # Use lexicographic sort for other tags
        sorted_tags = sorted(other_tags, reverse=True)
        print(sorted_tags[0])
    else:
        print('latest')
except Exception as e:
    print('Error:', e)
    exit(1)
" 2>/dev/null; then
        log_error "Failed to parse registry response"
        return 1
    fi
}

# Function to check if containers are healthy
check_container_health() {
    local container_name=$1
    local max_wait=$2
    local waited=0
    
    log "Checking health of container: $container_name"
    
    while [ $waited -lt $max_wait ]; do
        # Check if container is running
        if ! docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            log_warning "Container $container_name is not running"
            sleep $HEALTH_CHECK_INTERVAL
            waited=$((waited + HEALTH_CHECK_INTERVAL))
            continue
        fi
        
        # Check health status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        
        if [ "$health_status" = "healthy" ]; then
            log_success "Container $container_name is healthy"
            return 0
        elif [ "$health_status" = "no-healthcheck" ]; then
            # If no healthcheck defined, check if we can curl the health endpoint
            container_port=$(docker port "$container_name" 5000/tcp 2>/dev/null | cut -d':' -f2)
            if [ -n "$container_port" ]; then
                if curl -f -s "http://localhost:$container_port/health" > /dev/null 2>&1; then
                    log_success "Container $container_name is responding to health checks"
                    return 0
                fi
            fi
        fi
        
        log "Container $container_name health status: $health_status (waited ${waited}s)"
        sleep $HEALTH_CHECK_INTERVAL
        waited=$((waited + HEALTH_CHECK_INTERVAL))
    done
    
    log_error "Container $container_name failed health check after ${max_wait}s"
    return 1
}

# Function to backup current docker-compose.yml
backup_compose_file() {
    log "Creating backup of docker-compose.robots.yml"
    cp "$COMPOSE_FILE" "$BACKUP_COMPOSE_FILE"
    log_success "Backup created: $BACKUP_COMPOSE_FILE"
}

# Function to restore docker-compose.yml from backup
restore_compose_file() {
    log "Restoring docker-compose.robots.yml from backup"
    if [ -f "$BACKUP_COMPOSE_FILE" ]; then
        cp "$BACKUP_COMPOSE_FILE" "$COMPOSE_FILE"
        log_success "docker-compose.robots.yml restored from backup"
        return 0
    else
        log_error "Backup file not found: $BACKUP_COMPOSE_FILE"
        return 1
    fi
}

# Function to update docker-compose.yml with new image tag
update_compose_file() {
    local new_tag=$1
    local full_image="${REGISTRY_URL}/${IMAGE_NAME}:${new_tag}"
    
    log "Updating docker-compose.robots.yml to use image: $full_image"
    
    # Create a temporary file with the updated compose configuration
    python3 -c "
import re

with open('$COMPOSE_FILE', 'r') as f:
    content = f.read()

# For each robot service, replace build section with image
services = ['robot-1', 'robot-2', 'robot-3']
for service in services:
    # Pattern to match the service block
    service_pattern = f'({service}:.*?)(?=\\n\\s*[a-zA-Z-]+:|\\n[a-zA-Z-]+:|$)'
    
    def replace_build_with_image(match):
        service_block = match.group(1)
        
        # Remove build section if it exists
        build_pattern = r'\\n\\s+build:.*?(?=\\n\\s+[a-zA-Z-]+:|\\n\\s*$|$)'
        service_block = re.sub(build_pattern, '', service_block, flags=re.DOTALL)
        
        # Remove existing image line if it exists
        image_pattern = r'\\n\\s+image:.*?\\n'
        service_block = re.sub(image_pattern, '\\n', service_block)
        
        # Add image line after service name
        lines = service_block.split('\\n')
        result_lines = [lines[0]]  # service name line
        result_lines.append(f'    image: $full_image')
        result_lines.extend(lines[1:])  # rest of the service config
        
        return '\\n'.join(result_lines)
    
    content = re.sub(service_pattern, replace_build_with_image, content, flags=re.DOTALL)

with open('$COMPOSE_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "docker-compose.robots.yml updated successfully"
        return 0
    else
        log_error "Failed to update docker-compose.robots.yml"
        return 1
    fi
}

# Function to pull new image
pull_image() {
    local tag=$1
    local full_image="${REGISTRY_URL}/${IMAGE_NAME}:${tag}"
    
    log "Pulling image: $full_image"
    
    if docker pull "$full_image"; then
        log_success "Successfully pulled image: $full_image"
        return 0
    else
        log_error "Failed to pull image: $full_image"
        return 1
    fi
}

# Function to deploy containers
deploy_containers() {
    log "Deploying robot containers with docker compose..."
    
    # Stop and remove existing robot containers
    cd .. && docker compose -f docker-compose.robots.yml down
    
    # Start robot containers with new configuration
    if docker compose -f docker-compose.robots.yml up -d; then
        log_success "Robot containers deployed successfully"
        cd - > /dev/null
        return 0
    else
        log_error "Failed to deploy robot containers"
        cd - > /dev/null
        return 1
    fi
}

# Function to rollback deployment
rollback_deployment() {
    log_warning "Starting rollback process..."
    
    # Restore compose file
    if restore_compose_file; then
        # Deploy with old configuration
        if deploy_containers; then
            log_success "Rollback completed successfully"
            return 0
        else
            log_error "Rollback deployment failed"
            return 1
        fi
    else
        log_error "Rollback failed - could not restore compose file"
        return 1
    fi
}

# Function to verify all robot containers are healthy
verify_all_containers() {
    local containers=("robot-service-1" "robot-service-2" "robot-service-3")
    local failed_containers=()
    
    log "Verifying health of all robot containers..."
    
    for container in "${containers[@]}"; do
        if ! check_container_health "$container" "$HEALTH_CHECK_TIMEOUT"; then
            failed_containers+=("$container")
        fi
    done
    
    if [ ${#failed_containers[@]} -eq 0 ]; then
        log_success "All robot containers are healthy"
        return 0
    else
        log_error "Failed containers: ${failed_containers[*]}"
        return 1
    fi
}

# Main deployment function
main() {
    log "Starting auto-deployment process..."
    
    # Check if required files exist
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.robots.yml not found"
        exit 1
    fi
    
    # Get current and latest tags
    current_tag=$(get_current_tag)
    
    log "Checking for latest tag in registry ${REGISTRY_URL}/${IMAGE_NAME}..."
    latest_tag=$(get_latest_tag)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get latest tag from registry"
        exit 1
    fi
    
    log "Current tag: $current_tag"
    log "Latest tag: $latest_tag"
    
    # Check if update is needed
    if [ "$current_tag" = "$latest_tag" ]; then
        log_success "Already using the latest tag ($latest_tag). No update needed."
        exit 0
    fi
    
    log "New tag found: $latest_tag"
    
    # Start deployment process
    backup_compose_file
    
    # Pull new image
    if ! pull_image "$latest_tag"; then
        log_error "Failed to pull new image. Deployment aborted."
        exit 1
    fi
    
    # Update compose file
    if ! update_compose_file "$latest_tag"; then
        log_error "Failed to update compose file. Deployment aborted."
        exit 1
    fi
    
    # Deploy containers
    if ! deploy_containers; then
        log_error "Failed to deploy containers. Starting rollback..."
        rollback_deployment
        exit 1
    fi
    
    # Wait a moment for containers to start
    sleep 20
    
    # Verify all containers are healthy
    if ! verify_all_containers; then
        log_error "Health check failed for some containers. Starting rollback..."
        if rollback_deployment; then
            exit 1
        else
            log_error "Rollback failed! Manual intervention required."
            exit 2
        fi
    fi
    
    # Clean up backup if deployment was successful
    rm -f "$BACKUP_COMPOSE_FILE"
    
    log_success "Deployment completed successfully! All containers are healthy."
    log_success "Updated from tag '$current_tag' to '$latest_tag'"
}

# Parse command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Auto-deployment script for robot-app containers"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check-only   Only check for new tags, don't deploy"
        echo "  --force        Force deployment even if tags are the same"
        echo ""
        echo "The script will:"
        echo "  1. Check for new tags in local registry"
        echo "  2. Pull new images if available"
        echo "  3. Update and deploy containers"
        echo "  4. Verify health status"
        echo "  5. Rollback on failure"
        ;;
    "--check-only")
        current_tag=$(get_current_tag)
        latest_tag=$(get_latest_tag)
        echo "Current tag: $current_tag"
        echo "Latest tag: $latest_tag"
        if [ "$current_tag" != "$latest_tag" ]; then
            echo "Update available: $current_tag -> $latest_tag"
            exit 1
        else
            echo "No update available"
            exit 0
        fi
        ;;
    "--force")
        log "Force flag detected - will deploy regardless of tag comparison"
        # Temporarily modify the current tag check
        get_current_tag() { echo "force-deploy"; }
        main
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac