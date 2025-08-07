#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager API Environment Fix${NC}"
echo -e "${BLUE}=================================${NC}"

# Check system information
echo -e "${YELLOW}System Information:${NC}"
uname -a
echo "Architecture: $(uname -m)"
echo "User: $(whoami)"
echo "Directory: $(pwd)"

# Check Python environment
echo -e "${YELLOW}Python environment:${NC}"
which python3
python3 --version

# Check if virtual environment is active
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${GREEN}✓ Virtual environment is active: $VIRTUAL_ENV${NC}"
else
    echo -e "${YELLOW}No virtual environment is active${NC}"
    
    # Check if we can find a virtual environment
    if [ -d "../nlp_venv" ]; then
        echo -e "${BLUE}Found virtual environment at ../nlp_venv, activating...${NC}"
        source ../nlp_venv/bin/activate
        echo -e "${GREEN}✓ Activated virtual environment: $VIRTUAL_ENV${NC}"
    else
        echo -e "${YELLOW}Creating a new virtual environment...${NC}"
        python3 -m venv ../hnm_venv
        source ../hnm_venv/bin/activate
        echo -e "${GREEN}✓ Created and activated virtual environment: $VIRTUAL_ENV${NC}"
    fi
fi

# Navigate to the huddle-node-manager directory
cd ..
echo -e "${YELLOW}Current directory: $(pwd)${NC}"

# Fix PyTorch installation
echo -e "${YELLOW}Fixing PyTorch installation...${NC}"
echo -e "${BLUE}Uninstalling existing PyTorch...${NC}"
pip uninstall -y torch torchvision

# Install PyTorch for the correct architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo -e "${BLUE}Installing PyTorch for arm64 architecture...${NC}"
    pip install --no-cache-dir torch torchvision
else
    echo -e "${BLUE}Installing PyTorch for x86_64 architecture...${NC}"
    pip install --no-cache-dir torch torchvision
fi

# Create API key directory if it doesn't exist
API_KEY_DIR="$HOME/.ipfs/api_keys"
if [ ! -d "$API_KEY_DIR" ]; then
    echo -e "${BLUE}Creating API key directory: $API_KEY_DIR${NC}"
    mkdir -p "$API_KEY_DIR"
    echo -e "${GREEN}✓ Created API key directory${NC}"
    
    # Check if we have an existing API key
    if [ -f "$HOME/.ipfs/huddle_network_api_key" ]; then
        echo -e "${BLUE}Found existing API key, copying to new directory...${NC}"
        cp "$HOME/.ipfs/huddle_network_api_key" "$API_KEY_DIR/default.key"
        echo -e "${GREEN}✓ Copied API key to new location${NC}"
    else
        echo -e "${RED}✗ No existing API key found${NC}"
    fi
else
    echo -e "${GREEN}✓ API key directory already exists${NC}"
fi

# Install API requirements
if [ -f "api/requirements.txt" ]; then
    echo -e "${BLUE}Installing API requirements...${NC}"
    pip install -r api/requirements.txt
    echo -e "${GREEN}✓ Installed API requirements${NC}"
else
    echo -e "${RED}✗ API requirements file not found${NC}"
fi

# Create a Python script to test API imports
echo -e "${YELLOW}Creating Python test script...${NC}"
cat > api_env_test.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import importlib.util
import traceback

print("\n\033[1;33mPython Information:\033[0m")
print(f"Python version: {sys.version}")
print(f"Python executable: {sys.executable}")
print(f"Current directory: {os.getcwd()}")

# Try to import torch
print("\n\033[1;33mTesting PyTorch installation:\033[0m")
try:
    import torch
    print(f"\033[0;32m✓ PyTorch installed: {torch.__version__}\033[0m")
    print(f"\033[0;32m✓ CUDA available: {torch.cuda.is_available()}\033[0m")
    print(f"\033[0;32m✓ Device: {torch.device('cuda' if torch.cuda.is_available() else 'cpu')}\033[0m")
except ImportError as e:
    print(f"\033[0;31m✗ Failed to import torch: {e}\033[0m")
    print("\033[1;33mTraceback:\033[0m")
    traceback.print_exc()

# Try to import API modules
print("\n\033[1;33mTesting API imports:\033[0m")
try:
    sys.path.append(os.path.abspath("."))
    from api.apim import client
    print("\033[0;32m✓ Successfully imported api.apim.client\033[0m")
    
    # Check if client has necessary attributes/methods
    if hasattr(client, "APIClient"):
        print("\033[0;32m✓ APIClient class found\033[0m")
        
        # Try to create an instance
        try:
            api_client = client.APIClient()
            print("\033[0;32m✓ APIClient instance created\033[0m")
        except Exception as e:
            print(f"\033[0;31m✗ Failed to create APIClient instance: {e}\033[0m")
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

# Check for configuration file
config_path = os.path.expanduser("~/.ipfs/apim_config.json")
if os.path.exists(config_path):
    print(f"\033[0;32m✓ API configuration file found: {config_path}\033[0m")
    with open(config_path, 'r') as f:
        print("\033[1;33mConfiguration content:\033[0m")
        print(f.read())
else:
    print(f"\033[0;31m✗ API configuration file not found: {config_path}\033[0m")
EOF

# Make the test script executable
chmod +x api_env_test.py

# Run the Python test script
echo -e "${YELLOW}Running API environment test script...${NC}"
python3 api_env_test.py

echo -e "${GREEN}API environment fix completed!${NC}" 