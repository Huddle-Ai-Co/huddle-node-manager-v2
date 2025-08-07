#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Docker Cleanup Script${NC}"
echo -e "${BLUE}=================================${NC}"

echo -e "${YELLOW}Cleaning up Docker resources...${NC}"

# Stop and remove macOS container
container="hnm-macos"
if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
    echo -e "${BLUE}Stopping and removing $container container...${NC}"
    docker rm -f $container >/dev/null 2>&1
    echo -e "${GREEN}Container $container removed${NC}"
else
    echo -e "${BLUE}Container $container not found${NC}"
fi

# Remove macOS image
if docker images "hnm-macos" --format '{{.Repository}}' | grep -q "^hnm-macos$"; then
    echo -e "${BLUE}Removing hnm-macos image...${NC}"
    docker rmi hnm-macos >/dev/null 2>&1
    echo -e "${GREEN}Image hnm-macos removed${NC}"
else
    echo -e "${BLUE}Image hnm-macos not found${NC}"
fi

# Check if we're keeping the other images
for env in linux wsl mingw; do
    if docker images "hnm-$env" --format '{{.Repository}}' | grep -q "^hnm-$env$"; then
        echo -e "${GREEN}Keeping hnm-$env image${NC}"
    else
        echo -e "${YELLOW}hnm-$env image not found${NC}"
    fi
done

# Check Docker disk usage before and after
echo -e "${YELLOW}Docker disk usage:${NC}"
docker system df

echo -e "${GREEN}Cleanup complete!${NC}" 