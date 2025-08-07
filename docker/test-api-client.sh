#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager API Client Tester${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to test API client in a container
test_api_client() {
    local env=$1
    local container="hnm-$env"
    
    echo -e "${YELLOW}Testing API client in $env environment...${NC}"
    
    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${RED}Container $container is not running. Skipping...${NC}"
        return 1
    fi
    
    # Create a test script inside the container
    echo -e "${BLUE}Creating API client test script in container...${NC}"
    docker exec $container bash -c "cat > /tmp/test-api-client.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("api-client-test")

print('='*50)
print('HUDDLE NODE MANAGER API CLIENT TEST')
print('='*50)

print('Python version:', sys.version)
print('Current directory:', os.getcwd())

# Add necessary paths
sys.path.append('/home/huddle/.local/lib/huddle-node-manager')
sys.path.append('/home/huddle/.local/lib')

# Check API key
print('\\nChecking API key...')
api_key_file = Path.home() / '.ipfs' / 'huddleai_api_key'
if api_key_file.exists():
    with open(api_key_file, 'r') as f:
        key = f.read().strip()
        print(f'✅ API key found in file: {key[:4]}...{key[-4:]}')
else:
    print('❌ API key file not found')

# Try to import the API client
print('\\nImporting API client...')
try:
    from api.apim.client import client
    print('✅ API client imported successfully')
    
    # Check if API key exists in module
    from api.apim.common import api_key
    key = api_key.get_api_key()
    if key:
        print(f'✅ API key found in module: {key[:4]}...{key[-4:]}')
        
        # Verify API key
        print('\\nVerifying API key...')
        success, message = client.verify_api_key()
        if success:
            print(f'✅ API key verified: {message}')
        else:
            print(f'❌ API key verification failed: {message}')
        
        # Test available services
        print('\\nTesting available services:')
        
        # Test embeddings service
        print('\\n- Embeddings service:')
        try:
            models = client.embeddings.list_models()
            print(f'  ✅ Models available: {models}')
        except Exception as e:
            print(f'  ❌ Error: {e}')
        
        # Test OCR service
        print('\\n- OCR service:')
        try:
            health = client.ocr.check_health()
            print(f'  ✅ Health check: {health}')
        except Exception as e:
            print(f'  ❌ Error: {e}')
        
        # Test NLP service
        print('\\n- NLP service:')
        try:
            health = client.nlp.check_health()
            print(f'  ✅ Health check: {health}')
        except Exception as e:
            print(f'  ❌ Error: {e}')
        
        # Test Transcriber service
        print('\\n- Transcriber service:')
        try:
            health = client.transcriber.check_health()
            print(f'  ✅ Health check: {health}')
        except Exception as e:
            print(f'  ❌ Error: {e}')
    else:
        print('❌ No API key found from module')
except Exception as e:
    print(f'❌ Error importing API client: {e}')

print('\\nAPI client test completed.')
EOF"
    
    # Make the script executable
    docker exec $container bash -c "chmod +x /tmp/test-api-client.py"
    
    # Run the test script
    echo -e "${BLUE}Running API client test script...${NC}"
    docker exec $container bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && python3 /tmp/test-api-client.py"
    
    echo -e "${GREEN}API client test completed for $env environment${NC}"
}

# Main function
main() {
    # Test API client in each environment
    for env in linux wsl mingw macos; do
        test_api_client $env
        echo ""
    done
    
    echo -e "${GREEN}All API client tests completed!${NC}"
}

# Run the main function
main 