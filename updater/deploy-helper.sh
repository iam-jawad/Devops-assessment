#!/bin/bash

# Deployment helper script for Windows/WSL environment
# This script provides easy commands for managing the auto-deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/auto-deploy.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_usage() {
    echo -e "${GREEN}Robot App Deployment Helper${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy              Run full deployment process"
    echo "  check               Check for new tags without deploying"
    echo "  force               Force deployment regardless of tags"
    echo "  status              Check current deployment status"
    echo "  rollback            Manual rollback to previous version"
    echo "  logs                Show deployment logs"
    echo "  monitor             Start continuous monitoring"
    echo "  setup               Set up cron job for automatic deployments"
    echo ""
    echo "Examples:"
    echo "  $0 deploy           # Run deployment"
    echo "  $0 check            # Check for updates"
    echo "  $0 status           # Show container status"
    echo "  $0 monitor          # Start monitoring mode"
}

check_requirements() {
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
        return 1
    fi
    
    # Check if docker compose is available
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}Error: docker compose is not available${NC}"
        return 1
    fi
    
    # Check if the deploy script exists
    if [ ! -f "$DEPLOY_SCRIPT" ]; then
        echo -e "${RED}Error: Deploy script not found at $DEPLOY_SCRIPT${NC}"
        return 1
    fi
    
    # Make sure deploy script is executable
    chmod +x "$DEPLOY_SCRIPT"
    
    return 0
}

show_status() {
    echo -e "${GREEN}Current Deployment Status${NC}"
    echo "================================"
    
    # Show current image tags
    echo "Current robot containers:"
    cd .. && docker ps --filter "label=monitoring=robot" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    cd - > /dev/null
    
    echo ""
    echo "Health status:"
    for container in robot-service-1 robot-service-2 robot-service-3; do
        if docker ps -q --filter "name=$container" | grep -q .; then
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            echo "  $container: $health"
        else
            echo "  $container: not running"
        fi
    done
    
    echo ""
    echo "Registry status:"
    if curl -s http://localhost:5000/v2/_catalog > /dev/null 2>&1; then
        echo "  Local registry: accessible"
        tags=$(curl -s http://localhost:5000/v2/robot-app/tags/list 2>/dev/null | jq -r '.tags[]?' 2>/dev/null || echo "none")
        echo "  Available tags: $tags"
    else
        echo -e "  Local registry: ${RED}not accessible${NC}"
    fi
}

run_deployment() {
    echo -e "${GREEN}Starting deployment process...${NC}"
    if check_requirements; then
        "$DEPLOY_SCRIPT" "$@"
    else
        echo -e "${RED}Requirements check failed${NC}"
        return 1
    fi
}

run_monitoring() {
    echo -e "${GREEN}Starting monitoring mode...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        clear
        echo -e "${GREEN}Auto-Deployment Monitor${NC} - $(date)"
        echo "========================================"
        
        show_status
        
        echo ""
        echo "Checking for updates..."
        if "$DEPLOY_SCRIPT" --check-only; then
            echo -e "${GREEN}✓ Up to date${NC}"
        else
            echo -e "${YELLOW}⚠ Update available${NC}"
            echo "Run 'deploy' command to update"
        fi
        
        echo ""
        echo "Next check in 60 seconds..."
        sleep 60
    done
}

setup_cron() {
    echo -e "${GREEN}Setting up automatic deployment cron job...${NC}"
    
    # Create a cron job that runs every 5 minutes
    cron_job="*/5 * * * * cd $SCRIPT_DIR && ./auto-deploy.sh >> /var/log/auto-deploy.log 2>&1"
    
    # Add to crontab if not already present
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    echo "Cron job added: Deployment check every 5 minutes"
    echo "Logs will be written to: /var/log/auto-deploy.log"
    echo ""
    echo "To remove the cron job later, run: crontab -e"
}

manual_rollback() {
    echo -e "${YELLOW}Manual rollback requested${NC}"
    
    if [ -f "../docker-compose.robots.yml.backup" ]; then
        echo "Backup file found. Restoring..."
        cp ../docker-compose.robots.yml.backup ../docker-compose.robots.yml
        cd .. && docker compose -f docker-compose.robots.yml down && docker compose -f docker-compose.robots.yml up -d
        cd - > /dev/null
        echo -e "${GREEN}Rollback completed${NC}"
    else
        echo -e "${RED}No backup file found${NC}"
        echo "You may need to manually edit docker-compose.robots.yml"
    fi
}

show_logs() {
    if [ -f "/var/log/auto-deploy.log" ]; then
        tail -f /var/log/auto-deploy.log
    else
        echo "No log file found at /var/log/auto-deploy.log"
        echo "Try running a deployment first"
    fi
}

# Main command processing
case "${1:-help}" in
    "deploy")
        shift
        run_deployment "$@"
        ;;
    "check")
        run_deployment --check-only
        ;;
    "force")
        run_deployment --force
        ;;
    "status")
        show_status
        ;;
    "monitor")
        run_monitoring
        ;;
    "setup")
        setup_cron
        ;;
    "rollback")
        manual_rollback
        ;;
    "logs")
        show_logs
        ;;
    "help"|"--help"|"-h"|"")
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        print_usage
        exit 1
        ;;
esac