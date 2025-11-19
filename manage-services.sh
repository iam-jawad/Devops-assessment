#!/bin/bash

# DevOps Assessment - Service Management Script
# This script manages the complete system with separate infrastructure and robot services

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo -e "${GREEN}DevOps Assessment - Service Management${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start              Start all services (infrastructure + robots)"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  start-infra        Start only infrastructure services"
    echo "  start-robots       Start only robot services"
    echo "  stop-infra         Stop only infrastructure services"
    echo "  stop-robots        Stop only robot services"
    echo "  restart-robots     Restart only robot services"
    echo "  status             Show status of all services"
    echo "  logs               Show logs for all services"
    echo "  logs-robots        Show logs for robot services only"
    echo "  logs-infra         Show logs for infrastructure services only"
    echo "  help               Show this help message"
    echo ""
    echo "Infrastructure services: Prometheus, Grafana, Registry"
    echo "Robot services: robot-service-1, robot-service-2, robot-service-3"
}

start_infrastructure() {
    log_info "Starting infrastructure services..."
    docker compose -f docker-compose.infrastructure.yml up -d
    if [ $? -eq 0 ]; then
        log_success "Infrastructure services started"
        return 0
    else
        log_error "Failed to start infrastructure services"
        return 1
    fi
}

start_robots() {
    log_info "Starting robot services..."
    docker compose -f docker-compose.robots.yml up -d
    if [ $? -eq 0 ]; then
        log_success "Robot services started"
        return 0
    else
        log_error "Failed to start robot services"
        return 1
    fi
}

stop_infrastructure() {
    log_info "Stopping infrastructure services..."
    docker compose -f docker-compose.infrastructure.yml down
    if [ $? -eq 0 ]; then
        log_success "Infrastructure services stopped"
        return 0
    else
        log_error "Failed to stop infrastructure services"
        return 1
    fi
}

stop_robots() {
    log_info "Stopping robot services..."
    docker compose -f docker-compose.robots.yml down
    if [ $? -eq 0 ]; then
        log_success "Robot services stopped"
        return 0
    else
        log_error "Failed to stop robot services"
        return 1
    fi
}

show_status() {
    echo -e "${GREEN}Service Status${NC}"
    echo "============================================="
    
    echo -e "${YELLOW}Infrastructure Services:${NC}"
    docker compose -f docker-compose.infrastructure.yml ps
    
    echo ""
    echo -e "${YELLOW}Robot Services:${NC}"
    docker compose -f docker-compose.robots.yml ps
    
    echo ""
    echo -e "${YELLOW}Health Check Summary:${NC}"
    for container in robot-service-1 robot-service-2 robot-service-3; do
        if docker ps -q --filter "name=$container" | grep -q .; then
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            echo "  $container: $health"
        else
            echo "  $container: not running"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Service URLs:${NC}"
    echo "  Robot Services:    http://localhost:5001, http://localhost:5002, http://localhost:5003"
    echo "  Prometheus (1):    http://localhost:9090"
    echo "  Prometheus (2):    http://localhost:9091"
    echo "  Grafana:           http://localhost:3000 (admin/admin)"
    echo "  Registry:          http://localhost:5000"
}

case "${1:-help}" in
    "start")
        start_infrastructure && start_robots
        ;;
    "stop")
        stop_robots && stop_infrastructure
        ;;
    "restart")
        stop_robots && stop_infrastructure && start_infrastructure && start_robots
        ;;
    "start-infra"|"start-infrastructure")
        start_infrastructure
        ;;
    "start-robots")
        start_robots
        ;;
    "stop-infra"|"stop-infrastructure")
        stop_infrastructure
        ;;
    "stop-robots")
        stop_robots
        ;;
    "restart-robots")
        stop_robots && start_robots
        ;;
    "status")
        show_status
        ;;
    "logs")
        echo -e "${YELLOW}Infrastructure Services Logs:${NC}"
        docker compose -f docker-compose.infrastructure.yml logs --tail=50
        echo ""
        echo -e "${YELLOW}Robot Services Logs:${NC}"
        docker compose -f docker-compose.robots.yml logs --tail=50
        ;;
    "logs-robots")
        docker compose -f docker-compose.robots.yml logs --tail=50 -f
        ;;
    "logs-infra"|"logs-infrastructure")
        docker compose -f docker-compose.infrastructure.yml logs --tail=50 -f
        ;;
    "help"|"--help"|"-h")
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac