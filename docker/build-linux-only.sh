#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager - Linux Only Test${NC}"
echo -e "${BLUE}=================================${NC}"

# Detect host architecture
ARCH=$(uname -m)
echo -e "${BLUE}Detected host architecture: $ARCH ($(arch))${NC}"

# Set up architecture-specific environments
echo -e "${YELLOW}Setting up architecture-specific environments${NC}"

# Build Linux environment
echo -e "${YELLOW}Building Linux environment...${NC}"
docker buildx create --name multi-arch-builder --use
docker buildx inspect --bootstrap
docker buildx build --platform linux/amd64 -t hnm-linux -f Dockerfile.linux --load .

# Run tests in Linux environment
echo -e "${YELLOW}Running tests in Linux environment...${NC}"

# Remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^hnm-linux$"; then
    echo -e "${BLUE}Removing existing hnm-linux container...${NC}"
    docker rm -f hnm-linux >/dev/null 2>&1
fi

# Start the container with tty and keep it running
echo -e "${BLUE}Starting hnm-linux container...${NC}"
docker run -d --name hnm-linux -v $(pwd)/..:/home/huddle/huddle-node-manager --entrypoint "/bin/bash" hnm-linux -c "tail -f /dev/null"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^hnm-linux$"; then
    echo -e "${RED}Failed to start hnm-linux container.${NC}"
    exit 1
fi

# Copy the test script to the container
echo -e "${BLUE}Copying test script to container...${NC}"
docker cp $(pwd)/scripts/test-install.sh hnm-linux:/home/huddle/test-install.sh
docker exec hnm-linux bash -c "chmod +x /home/huddle/test-install.sh"

# Run the test script
echo -e "${BLUE}Running test script in container...${NC}"
docker exec hnm-linux bash -c "/home/huddle/test-install.sh"

echo -e "${GREEN}Linux environment build and test complete!${NC}" 