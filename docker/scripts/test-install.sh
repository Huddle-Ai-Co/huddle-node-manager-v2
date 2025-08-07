#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Fresh Installation Test${NC}"
echo -e "${BLUE}=================================${NC}"

# Check system information
echo -e "${YELLOW}System Information:${NC}"
uname -a
echo "Architecture: $(uname -m)"
echo "User: $(whoami)"
echo "Directory: $(pwd)"

# Simulate fresh installation by downloading HNM repository
echo -e "${YELLOW}Simulating fresh HNM installation...${NC}"

# Create a temporary directory for the fresh installation
FRESH_INSTALL_DIR="/tmp/hnm-fresh-install"
echo -e "${BLUE}Creating fresh installation directory: $FRESH_INSTALL_DIR${NC}"
mkdir -p "$FRESH_INSTALL_DIR"
cd "$FRESH_INSTALL_DIR"

# Copy the distribution package to simulate fresh download
echo -e "${BLUE}Copying HNM distribution package to simulate fresh download...${NC}"
cp -r /home/huddle/huddle-node-manager-distribution/* .

# Verify we have the installation files
echo -e "${YELLOW}Verifying installation files:${NC}"
ls -la

# Check if we have the core installation script
if [ -f "install-hnm.sh" ]; then
    echo -e "${GREEN}✓ Found install-hnm.sh${NC}"
    chmod +x install-hnm.sh
else
    echo -e "${RED}✗ install-hnm.sh not found${NC}"
    echo -e "${BLUE}Available files:${NC}"
    ls -la
    exit 1
fi

# Create a non-interactive answer file for the installation script
echo -e "${BLUE}Creating answer file for non-interactive installation...${NC}"
cat > /tmp/answers.txt << 'ANSWERS'
1
1
ANSWERS

# Run the installation script with answers piped in
echo -e "${BLUE}Running HNM installation script...${NC}"
cat /tmp/answers.txt | ./install-hnm.sh

# Source the updated PATH
echo -e "${BLUE}Sourcing updated PATH...${NC}"
export PATH="$HOME/.local/bin:$PATH"

# Check if HNM was installed
if command -v hnm &> /dev/null; then
    echo -e "${GREEN}✓ HNM was installed successfully!${NC}"
    echo -e "${BLUE}HNM version:${NC}"
    hnm --version
    
    # Test basic HNM commands
    echo -e "${BLUE}Testing basic HNM commands:${NC}"
    hnm help
    
    # Test the new CLI commands
    echo -e "${BLUE}Testing new CLI commands:${NC}"
    hnm docker list
    hnm test dynamic
else
    echo -e "${RED}✗ HNM installation failed or not found in PATH${NC}"
    echo -e "${BLUE}Checking if HNM exists in ~/.local/bin:${NC}"
    ls -la $HOME/.local/bin/ | grep hnm || echo "HNM not found in ~/.local/bin"
fi

# Testing production directory structure
echo -e "\n${YELLOW}Testing production directory structure:${NC}"
PROD_DIR="$HOME/.huddle-node-manager"
if [ -d "$PROD_DIR" ]; then
    echo -e "${GREEN}✓ Production directory exists: $PROD_DIR${NC}"
    ls -la "$PROD_DIR"
else
    echo -e "${RED}✗ Production directory not found: $PROD_DIR${NC}"
fi

# Check if API directory exists in the installed location
API_DIR="$HOME/.local/lib/huddle-node-manager/api"
if [ -d "$API_DIR" ]; then
    echo -e "${GREEN}✓ API directory found in production location${NC}"
    
    # Create a Python script to test API imports
    echo -e "${BLUE}Creating Python test script...${NC}"
    cat > /tmp/api_test.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import traceback

print("\nPython Information:")
print(f"Python version: {sys.version}")
print(f"Python executable: {sys.executable}")
print(f"Current directory: {os.getcwd()}")

# Add the production API directory to path
api_dir = os.path.expanduser("~/.local/lib/huddle-node-manager/api")
if os.path.exists(api_dir):
    sys.path.append(api_dir)
    print(f"✓ Added API directory to path: {api_dir}")

# Try to import API modules
print("\nTesting API imports:")
try:
    from apim import client
    print("✓ Successfully imported apim.client")
    
    # Check if client is an instance of APIMClient
    if hasattr(client, "__class__") and client.__class__.__name__ == "APIMClient":
        print("✓ client is an instance of APIMClient")
    else:
        print("✗ client is not an instance of APIMClient")
        
except ImportError as e:
    print(f"✗ Failed to import apim.client: {e}")
    traceback.print_exc()
EOF
    
    # Run the Python test script
    echo -e "${BLUE}Running API test script...${NC}"
    python3 /tmp/api_test.py
else
    echo -e "${RED}✗ API directory not found in production location${NC}"
fi

# Test the testing infrastructure
echo -e "\n${YELLOW}Testing HNM testing infrastructure:${NC}"
TESTING_DIR="$HOME/.local/lib/huddle-node-manager/testing"
if [ -d "$TESTING_DIR" ]; then
    echo -e "${GREEN}✓ Testing directory exists: $TESTING_DIR${NC}"
    ls -la "$TESTING_DIR"
else
    echo -e "${RED}✗ Testing directory not found: $TESTING_DIR${NC}"
fi

# Test Docker infrastructure
echo -e "\n${YELLOW}Testing HNM Docker infrastructure:${NC}"
DOCKER_DIR="$HOME/.local/lib/huddle-node-manager/docker"
if [ -d "$DOCKER_DIR" ]; then
    echo -e "${GREEN}✓ Docker directory exists: $DOCKER_DIR${NC}"
    ls -la "$DOCKER_DIR"
else
    echo -e "${RED}✗ Docker directory not found: $DOCKER_DIR${NC}"
fi

echo -e "\n${GREEN}✅ Fresh installation test completed successfully!${NC}" 