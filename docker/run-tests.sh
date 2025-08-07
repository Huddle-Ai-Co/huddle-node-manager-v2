#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Automated Tests${NC}"
echo -e "${BLUE}=================================${NC}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Function to run tests in a specific environment
run_tests_in_env() {
    local env=$1
    local container="hnm-$env"
    
    echo -e "\n${YELLOW}Running tests in $env environment...${NC}"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${BLUE}Starting $env environment...${NC}"
        docker-compose up -d $env
    fi
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${BLUE}Starting $container container...${NC}"
        docker start $container
    fi
    
    # Copy test script to container
    echo -e "${BLUE}Copying test script to container...${NC}"
    docker cp test-install.sh $container:/home/huddle/test-install.sh
    docker exec $container chmod +x /home/huddle/test-install.sh
    
    # Run non-interactive installation test
    echo -e "${BLUE}Running automated installation test in $env environment...${NC}"
    docker exec $container bash -c "cd /home/huddle && ./install-hnm.sh --yes"
    
    # Check installation
    echo -e "${BLUE}Checking installation in $env environment...${NC}"
    docker exec $container bash -c "which hnm || echo 'HNM not found in PATH'"
    docker exec $container bash -c "which ipfs || echo 'IPFS not found in PATH'"
    
    # Test HNM commands
    echo -e "${BLUE}Testing HNM commands in $env environment...${NC}"
    docker exec $container bash -c "hnm --version || echo 'HNM version command failed'"
    docker exec $container bash -c "hnm status || echo 'HNM status command failed'"
    
    echo -e "${GREEN}Tests completed for $env environment${NC}"
}

# Function to run tests in all environments
run_all_tests() {
    # Build environments if needed
    echo -e "${YELLOW}Building Docker environments...${NC}"
    docker-compose build
    
    # Run tests in each environment
    run_tests_in_env "linux"
    run_tests_in_env "wsl"
    run_tests_in_env "mingw"
    run_tests_in_env "macos"
    
    echo -e "\n${GREEN}All tests completed!${NC}"
}

# Function to show test results
show_test_results() {
    echo -e "\n${YELLOW}Test Results Summary:${NC}"
    
    for env in linux wsl mingw macos; do
        local container="hnm-$env"
        echo -e "\n${BLUE}$env Environment:${NC}"
        
        # Check if HNM is installed
        if docker exec $container which hnm >/dev/null 2>&1; then
            echo -e "${GREEN}✓ HNM installed${NC}"
        else
            echo -e "${RED}✗ HNM not installed${NC}"
        fi
        
        # Check if IPFS is installed
        if docker exec $container which ipfs >/dev/null 2>&1; then
            echo -e "${GREEN}✓ IPFS installed${NC}"
        else
            echo -e "${RED}✗ IPFS not installed${NC}"
        fi
        
        # Check HNM version
        local hnm_version=$(docker exec $container hnm --version 2>/dev/null || echo "N/A")
        echo -e "${BLUE}HNM Version:${NC} $hnm_version"
    done
}

# Function to clean up after tests
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test environments...${NC}"
    docker-compose down
    echo -e "${GREEN}Cleanup complete!${NC}"
}

# Main function
main() {
    case "$1" in
        run)
            run_all_tests
            show_test_results
            ;;
        clean)
            cleanup
            ;;
        *)
            echo -e "${YELLOW}Usage:${NC}"
            echo -e "  $0 run    - Run tests in all environments"
            echo -e "  $0 clean  - Clean up test environments"
            exit 1
            ;;
    esac
}

# Run the main function
main "$@" 