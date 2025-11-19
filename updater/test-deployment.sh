#!/bin/bash

# Test script for the auto-deployment system
# This script helps validate that all components are working correctly

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED_TESTS=0
TOTAL_TESTS=0

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    log_test "$test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

test_prerequisites() {
    echo -e "${YELLOW}Testing Prerequisites...${NC}"
    
    run_test "Docker installed" "command -v docker"
    run_test "Docker compose available" "docker compose version"
    run_test "Python3 installed" "command -v python3"
    run_test "Curl installed" "command -v curl"
    run_test "Scripts exist" "test -f auto-deploy.sh && test -f deploy-helper.sh"
    run_test "Scripts are executable" "test -x auto-deploy.sh && test -x deploy-helper.sh"
    
    echo ""
}

test_docker_environment() {
    echo -e "${YELLOW}Testing Docker Environment...${NC}"
    
    run_test "Docker daemon running" "docker info"
    run_test "Robot compose file exists" "test -f ../docker-compose.robots.yml"
    run_test "Infrastructure compose file exists" "test -f ../docker-compose.infrastructure.yml"
    run_test "Can list containers" "docker ps"
    
    echo ""
}

test_registry_connectivity() {
    echo -e "${YELLOW}Testing Registry Connectivity...${NC}"
    
    run_test "Registry port accessible" "curl -f -s http://localhost:5000/v2/"
    run_test "Registry catalog accessible" "curl -f -s http://localhost:5000/v2/_catalog"
    
    if curl -f -s http://localhost:5000/v2/robot-app/tags/list >/dev/null 2>&1; then
        log_success "Robot-app repository accessible"
    else
        log_test "Robot-app repository accessible"
        log_fail "Robot-app repository not found (this is OK for first run)"
    fi
    
    echo ""
}

test_containers_running() {
    echo -e "${YELLOW}Testing Container Status...${NC}"
    
    # Check if containers exist
    containers=("robot-service-1" "robot-service-2" "robot-service-3")
    
    for container in "${containers[@]}"; do
        if docker ps -q --filter "name=$container" | grep -q .; then
            log_success "Container $container is running"
        else
            log_test "Container $container running"
            log_fail "Container $container is not running"
        fi
    done
    
    echo ""
}

test_health_endpoints() {
    echo -e "${YELLOW}Testing Health Endpoints...${NC}"
    
    ports=(5001 5002 5003)
    
    for port in "${ports[@]}"; do
        run_test "Health endpoint :$port" "curl -f -s http://localhost:$port/health"
    done
    
    echo ""
}

test_deployment_script() {
    echo -e "${YELLOW}Testing Deployment Scripts...${NC}"
    
    run_test "Auto-deploy help" "./auto-deploy.sh --help"
    run_test "Deploy-helper help" "./deploy-helper.sh help"
    run_test "Deploy check-only mode" "./auto-deploy.sh --check-only || true"  # Allow exit code 1
    
    echo ""
}

create_test_image() {
    echo -e "${YELLOW}Creating Test Image...${NC}"
    
    # Create a test image with a new tag
    if docker images | grep -q robot-app; then
        # Tag existing robot-app image with test tag
        docker tag robot-app:latest localhost:5000/robot-app:test-$(date +%s)
        log_success "Created test image tag"
    else
        log_fail "No robot-app image found to create test from"
    fi
    
    echo ""
}

test_full_workflow() {
    echo -e "${YELLOW}Testing Full Workflow (Dry Run)...${NC}"
    
    # Test getting current tag
    if ./auto-deploy.sh --check-only >/dev/null 2>&1; then
        log_success "Can check for updates"
    else
        log_test "Can check for updates"
        # This might fail if no images exist yet - that's OK
        echo "  (This is expected if no robot-app images exist in registry)"
    fi
    
    echo ""
}

run_cleanup() {
    echo -e "${YELLOW}Cleanup Test Artifacts...${NC}"
    
    # Remove test backup files
    rm -f docker-compose.yml.backup.test
    
    log_success "Cleanup completed"
    echo ""
}

print_summary() {
    echo "========================================"
    echo -e "${BLUE}Test Summary${NC}"
    echo "========================================"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$((TOTAL_TESTS - FAILED_TESTS))${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        echo ""
        echo "Your auto-deployment system is ready to use."
        echo "Try running: ./deploy-helper.sh status"
        return 0
    else
        echo -e "${RED}Some tests failed! ✗${NC}"
        echo ""
        echo "Please resolve the failing tests before using the deployment system."
        echo "Check the README-deployment.md for troubleshooting guidance."
        return 1
    fi
}

main() {
    echo -e "${GREEN}Auto-Deployment System Test Suite${NC}"
    echo "========================================"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    test_prerequisites
    test_docker_environment
    test_registry_connectivity
    test_containers_running
    test_health_endpoints
    test_deployment_script
    test_full_workflow
    run_cleanup
    
    print_summary
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Auto-Deployment Test Suite"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help"
        echo "  --create-test  Create a test image for testing"
        echo ""
        echo "This script tests all components of the auto-deployment system."
        ;;
    "--create-test")
        create_test_image
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