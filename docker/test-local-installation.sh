#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Local Installation Test${NC}"
echo -e "${BLUE}=================================${NC}"

# Check system information
echo -e "${YELLOW}System Information:${NC}"
uname -a
echo "Architecture: $(uname -m)"
echo "User: $(whoami)"
echo "Directory: $(pwd)"

# Navigate to the huddle-node-manager directory
cd ..
echo -e "${YELLOW}Current directory: $(pwd)${NC}"

# Check if we can access the huddle-node-manager directory
echo -e "${YELLOW}Checking huddle-node-manager directory:${NC}"
ls -la

# Create a test directory for installation
TEST_DIR="/tmp/hnm-test-$(date +%s)"
echo -e "${YELLOW}Creating test directory: ${TEST_DIR}${NC}"
mkdir -p "${TEST_DIR}"

# Copy necessary files to test directory
echo -e "${YELLOW}Copying installation files to test directory...${NC}"
cp install-hnm.sh "${TEST_DIR}/"
cp -r api "${TEST_DIR}/" 2>/dev/null || echo -e "${YELLOW}No api directory to copy${NC}"
cp -r models "${TEST_DIR}/" 2>/dev/null || echo -e "${YELLOW}No models directory to copy${NC}"
cp -r docs "${TEST_DIR}/" 2>/dev/null || echo -e "${YELLOW}No docs directory to copy${NC}"

# Navigate to the test directory
cd "${TEST_DIR}"
echo -e "${YELLOW}Changed to test directory: $(pwd)${NC}"

# Try to run the installation script
echo -e "${YELLOW}Testing HNM installation script:${NC}"
if [ -f install-hnm.sh ]; then
    echo -e "${BLUE}Found install-hnm.sh, making it executable...${NC}"
    chmod +x install-hnm.sh
    
    # Create a non-interactive answer file for the installation script
    echo -e "${BLUE}Creating answer file for non-interactive installation...${NC}"
    cat > /tmp/answers.txt << 'ANSWERS'
1
1
ANSWERS
    
    # Run the installation script with answers piped in
    echo -e "${BLUE}Running installation script...${NC}"
    cat /tmp/answers.txt | ./install-hnm.sh || echo -e "${RED}Installation failed${NC}"
    
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
    else
        echo -e "${RED}✗ HNM installation failed or not found in PATH${NC}"
        echo -e "${BLUE}Checking if HNM exists in ~/.local/bin:${NC}"
        ls -la $HOME/.local/bin/ | grep hnm || echo "HNM not found in ~/.local/bin"
    fi
else
    echo -e "${RED}✗ install-hnm.sh not found${NC}"
fi

# Clean up
echo -e "${YELLOW}Cleaning up test directory...${NC}"
cd /tmp
rm -rf "${TEST_DIR}"

echo -e "${GREEN}All tests completed!${NC}" 