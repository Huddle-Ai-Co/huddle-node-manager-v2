#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager API Dependencies Installer${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to install dependencies in a container
install_dependencies() {
    local env=$1
    local container="hnm-$env"
    
    echo -e "${YELLOW}Installing API dependencies in $env environment...${NC}"
    
    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${RED}Container $container is not running. Starting it...${NC}"
        
        # Remove existing container if it exists but not running
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
            echo -e "${BLUE}Removing existing $container container...${NC}"
            docker rm -f $container >/dev/null 2>&1
        fi
        
        # Start the container with tty and keep it running
        echo -e "${BLUE}Starting $container container...${NC}"
        docker run -d --name $container -v $(pwd)/..:/home/huddle/huddle-node-manager --entrypoint "/bin/bash" hnm-$env -c "tail -f /dev/null"
        
        # Check if container started successfully
        if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
            echo -e "${RED}Failed to start $container container.${NC}"
            return 1
        fi
    fi
    
    # Install system dependencies for OpenCV and other libraries
    echo -e "${BLUE}Installing system dependencies...${NC}"
    docker exec $container bash -c "sudo apt-get update && sudo apt-get install -y libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 libfontconfig1"
    
    # Fix permissions on the API directory
    echo -e "${BLUE}Fixing permissions on API directory...${NC}"
    docker exec $container bash -c "sudo chown -R huddle:huddle /home/huddle/.local/lib/huddle-node-manager/api"
    
    # Create a test script inside the container
    echo -e "${BLUE}Creating API test script in container...${NC}"
    docker exec $container bash -c "cat > /tmp/api-test.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
from pathlib import Path

print('Python version:', sys.version)
print('Current directory:', os.getcwd())

# Add necessary paths
sys.path.append('/home/huddle/.local/lib/huddle-node-manager')
sys.path.append('/home/huddle/.local/lib')

# Check API key
api_key_file = Path.home() / '.ipfs' / 'huddle_network_api_key'
if api_key_file.exists():
    with open(api_key_file, 'r') as f:
        key = f.read().strip()
        print(f'API key found: {key[:4]}...{key[-4:]}')
else:
    print('API key file not found')

# Try to import the API client
try:
    from api.apim.client import client
    print('API client imported successfully')
    
    # Check if API key exists
    from api.apim.common import api_key
    key = api_key.get_api_key()
    if key:
        print(f'API key from module: {key[:4]}...{key[-4:]}')
    else:
        print('No API key found from module')
except Exception as e:
    print(f'Error importing API client: {e}')

# List the API directory structure
print('\nAPI directory structure:')
api_dir = Path('/home/huddle/.local/lib/huddle-node-manager/api')
if api_dir.exists():
    for item in api_dir.glob('**/*'):
        if item.is_file():
            print(f'  {item.relative_to(api_dir)}')
else:
    print('  API directory not found')
EOF"
    
    # Make the script executable
    docker exec $container bash -c "chmod +x /tmp/api-test.py"
    
    # Run the test script
    echo -e "${BLUE}Running API test script...${NC}"
    docker exec $container bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && python3 /tmp/api-test.py"
    
    echo -e "${GREEN}Dependencies installation completed for $env environment${NC}"
}

# Main function
main() {
    # Install dependencies in each environment
    for env in linux wsl mingw macos; do
        install_dependencies $env
    done
    
    echo -e "${GREEN}All dependencies installed!${NC}"
}

# Run the main function
main 