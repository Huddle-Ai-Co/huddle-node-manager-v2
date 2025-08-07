#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager API Test${NC}"
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

# Check if API directory exists
if [ -d "api" ]; then
    echo -e "${GREEN}✓ API directory found${NC}"
    echo -e "${YELLOW}API directory contents:${NC}"
    ls -la api/
else
    echo -e "${RED}✗ API directory not found${NC}"
    exit 1
fi

# Check for API key manager script
if [ -f "api_key_manager.sh" ]; then
    echo -e "${GREEN}✓ API key manager script found${NC}"
    echo -e "${YELLOW}Making script executable...${NC}"
    chmod +x api_key_manager.sh
else
    echo -e "${RED}✗ API key manager script not found${NC}"
    exit 1
fi

# Create a test directory
TEST_DIR="/tmp/hnm-api-test-$(date +%s)"
echo -e "${YELLOW}Creating test directory: ${TEST_DIR}${NC}"
mkdir -p "${TEST_DIR}"

# Copy API files to test directory
echo -e "${YELLOW}Copying API files to test directory...${NC}"
cp -r api "${TEST_DIR}/"
cp api_key_manager.sh "${TEST_DIR}/"

# Navigate to test directory
cd "${TEST_DIR}"
echo -e "${YELLOW}Changed to test directory: $(pwd)${NC}"

# Check for API requirements file
if [ -f "api/requirements.txt" ]; then
    echo -e "${GREEN}✓ API requirements file found${NC}"
    echo -e "${YELLOW}API requirements:${NC}"
    cat api/requirements.txt
else
    echo -e "${RED}✗ API requirements file not found${NC}"
fi

# Create a Python script to test API imports
echo -e "${YELLOW}Creating Python test script...${NC}"
cat > api_test.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import importlib.util
import traceback

print("\n\033[1;33mPython Information:\033[0m")
print(f"Python version: {sys.version}")
print(f"Python executable: {sys.executable}")
print(f"Current directory: {os.getcwd()}")

# Try to import API modules
print("\n\033[1;33mTesting API imports:\033[0m")

# Check if api directory exists
if os.path.isdir("api"):
    print("\033[0;32m✓ API directory found\033[0m")
    print("\033[1;33mAPI directory structure:\033[0m")
    for root, dirs, files in os.walk("api"):
        level = root.replace("api", "").count(os.sep)
        indent = " " * 4 * level
        print(f"{indent}{os.path.basename(root)}/")
        sub_indent = " " * 4 * (level + 1)
        for file in files:
            print(f"{sub_indent}{file}")
else:
    print("\033[0;31m✗ API directory not found\033[0m")
    sys.exit(1)

# Try to import apim module
try:
    sys.path.append(os.path.abspath("api"))
    from api.apim import client
    print("\033[0;32m✓ Successfully imported api.apim.client\033[0m")
    
    # Check if client has necessary attributes/methods
    if hasattr(client, "APIClient"):
        print("\033[0;32m✓ APIClient class found\033[0m")
    else:
        print("\033[0;31m✗ APIClient class not found\033[0m")
        
except ImportError as e:
    print(f"\033[0;31m✗ Failed to import api.apim.client: {e}\033[0m")
    print("\033[1;33mTraceback:\033[0m")
    traceback.print_exc()

# Check for API key
print("\n\033[1;33mChecking for API key:\033[0m")
api_key_path = os.path.expanduser("~/.ipfs/api_keys")
if os.path.exists(api_key_path):
    print(f"\033[0;32m✓ API key directory found: {api_key_path}\033[0m")
    # List files in the directory
    files = os.listdir(api_key_path)
    if files:
        print("\033[0;32m✓ API key files found:\033[0m")
        for file in files:
            print(f"  - {file}")
    else:
        print("\033[0;31m✗ No API key files found\033[0m")
else:
    print(f"\033[0;31m✗ API key directory not found: {api_key_path}\033[0m")
EOF

# Make the test script executable
chmod +x api_test.py

# Run the Python test script
echo -e "${YELLOW}Running API test script...${NC}"
python3 api_test.py

# Try to run the API key manager
echo -e "${YELLOW}Testing API key manager...${NC}"
./api_key_manager.sh list || echo -e "${RED}API key manager failed${NC}"

# Clean up
echo -e "${YELLOW}Cleaning up test directory...${NC}"
cd /tmp
rm -rf "${TEST_DIR}"

echo -e "${GREEN}API component tests completed!${NC}" 