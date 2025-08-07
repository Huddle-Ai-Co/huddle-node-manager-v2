#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set up fake proc for WSL simulation
if [ -d /docker-proc ]; then
    # Mount the fake proc
    mount --bind /docker-proc/proc /proc
    
    # Verify the mount worked
    if grep -q Microsoft /proc/version; then
        echo -e "${GREEN}Successfully simulated WSL environment${NC}"
    else
        echo -e "${RED}Failed to simulate WSL environment${NC}"
    fi
fi

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager - WSL Test Environment${NC}"
echo -e "${BLUE}=================================${NC}"

echo -e "${YELLOW}This container simulates a Windows Subsystem for Linux environment.${NC}"
echo -e "${YELLOW}You can test the HNM installation by running:${NC}"
echo -e "${GREEN}hnm setup${NC}"

# Set up environment for API testing
echo -e "\n${BLUE}Setting up environment for API testing:${NC}"
# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"
echo -e "${GREEN}✓ Added ~/.local/bin to PATH${NC}"

# Create API key directory
mkdir -p $HOME/.ipfs/api_keys
echo -e "${GREEN}✓ Created API key directory${NC}"

echo -e "\n${BLUE}Environment Information:${NC}"
echo -e "OS: $(uname -a)"
echo -e "WSL: $(cat /proc/version)"
echo -e "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo -e "Current directory: $(pwd)"
echo -e "PATH: $PATH"

# Check if test script exists
if [ -f ~/test-install.sh ]; then
    echo -e "\n${YELLOW}A test script is available. You can run it with:${NC}"
    echo -e "${GREEN}~/test-install.sh${NC}"
fi

echo -e "\n${YELLOW}After installation, you can test the HNM commands with:${NC}"
echo -e "${GREEN}hnm help${NC}"
echo -e "${GREEN}hnm test dynamic${NC}"
echo -e "${GREEN}hnm script device_detection_test.py${NC}"

# Start bash
exec bash