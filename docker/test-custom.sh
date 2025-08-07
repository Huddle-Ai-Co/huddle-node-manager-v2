#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Test Environments${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to test a container
test_container() {
    local env=$1
    local container="hnm-$env"
    
    echo -e "\n${YELLOW}Testing $env environment...${NC}"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${RED}Container $container is not running. Starting it...${NC}"
        docker start $container
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to start $container. Creating it...${NC}"
            docker-compose up -d $env
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to create $container. Skipping tests.${NC}"
                return 1
            fi
        fi
    fi
    
    # Run basic commands in the container
    echo -e "\n${BLUE}Basic system information for $env:${NC}"
    docker exec $container bash -c "uname -a && echo 'User: \$(whoami)' && echo 'Directory: \$(pwd)'"
    
    # Check what's in the huddle-node-manager directory
    echo -e "\n${BLUE}Contents of huddle-node-manager directory:${NC}"
    docker exec $container bash -c "ls -la huddle-node-manager"
    
    # Test if we can create a file
    echo -e "\n${BLUE}Testing file creation:${NC}"
    docker exec $container bash -c "echo 'Test file content' > test_file.txt && cat test_file.txt"
    
    # Test environment-specific commands
    case $env in
        linux)
            echo -e "\n${BLUE}Linux-specific tests:${NC}"
            docker exec $container bash -c "cat /etc/os-release"
            ;;
        wsl)
            echo -e "\n${BLUE}WSL-specific tests:${NC}"
            docker exec $container bash -c "ls -la /mnt/c || echo 'WSL mount point not accessible'"
            ;;
        mingw)
            echo -e "\n${BLUE}MinGW-specific tests:${NC}"
            docker exec $container bash -c "ls -la /c || echo 'MinGW mount point not accessible'"
            ;;
        macos)
            echo -e "\n${BLUE}macOS-specific tests:${NC}"
            docker exec $container bash -c "ls -la ~/Library || echo 'macOS Library directory not accessible'"
            ;;
    esac
    
    echo -e "\n${GREEN}Tests completed for $env environment${NC}"
}

# Test all environments
test_container "linux"
test_container "wsl"
test_container "mingw"
test_container "macos"

echo -e "\n${GREEN}All tests completed!${NC}" 