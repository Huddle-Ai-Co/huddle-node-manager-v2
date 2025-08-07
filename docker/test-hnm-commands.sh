#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Command Tests${NC}"
echo -e "${BLUE}=================================${NC}"

# Test API key
API_KEY="5b19fd57ad93422cb6c9dde2baba2df7"

# Function to run tests in a specific environment
run_command_tests() {
    local env=$1
    local container="hnm-$env"
    
    echo -e "${YELLOW}Running command tests in $env environment...${NC}"
    
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
    
    # Create test script inside the container
    echo -e "${BLUE}Creating command test script in container...${NC}"
    
    docker exec $container bash -c "cat > /tmp/command-test.sh << 'EOF'
#!/bin/bash

# Colors for output
GREEN='\\\033[0;32m'
YELLOW='\\\033[1;33m'
BLUE='\\\033[0;34m'
RED='\\\033[0;31m'
NC='\\\033[0m' # No Color

# Header
echo -e \"\${BLUE}=================================\${NC}\"
echo -e \"\${GREEN}Huddle Node Manager Command Test\${NC}\"
echo -e \"\${BLUE}=================================\${NC}\"

# API key
API_KEY=\"5b19fd57ad93422cb6c9dde2baba2df7\"

# Ensure PATH includes ~/.local/bin
export PATH=\"\$HOME/.local/bin:\$PATH\"

# Verify HNM is installed
if ! command -v hnm &> /dev/null; then
    echo -e \"\${RED}HNM is not installed or not in PATH\${NC}\"
    exit 1
fi

echo -e \"\${YELLOW}HNM Version:\${NC}\"
hnm --version

# Setup HNM with API key
echo -e \"\${YELLOW}Setting up HNM with API key...\${NC}\"
mkdir -p \$HOME/.ipfs/keys
echo \"\$API_KEY\" > \$HOME/.ipfs/keys/api_key.txt
echo \"\$API_KEY\" > \$HOME/.ipfs/huddle_network_api_key
echo -e \"\${GREEN}API key configured\${NC}\"

# Initialize IPFS
echo -e \"\${YELLOW}Initializing IPFS...\${NC}\"
hnm setup --non-interactive || echo -e \"\${RED}Failed to initialize IPFS\${NC}\"

# Start IPFS daemon
echo -e \"\${YELLOW}Starting IPFS daemon...\${NC}\"
hnm start || echo -e \"\${RED}Failed to start IPFS daemon\${NC}\"

# Wait for IPFS daemon to start
echo -e \"\${YELLOW}Waiting for IPFS daemon to start...\${NC}\"
sleep 5

# Test files
echo -e \"\${YELLOW}Testing file operations...\${NC}\"

# Test with PDF file
echo -e \"\${BLUE}Testing with PDF file...\${NC}\"
cp /home/huddle/huddle-node-manager/Data/RSSC_Stockton_Arts_Grant_\\(SAG\\)_Application.pdf /tmp/
echo -e \"\${BLUE}Adding PDF file to IPFS...\${NC}\"
hnm content add /tmp/RSSC_Stockton_Arts_Grant_\\(SAG\\)_Application.pdf || echo -e \"\${RED}Failed to add PDF file\${NC}\"

# Test with DOCX file
echo -e \"\${BLUE}Testing with DOCX file...\${NC}\"
cp /home/huddle/huddle-node-manager/Data/sample.docx /tmp/
echo -e \"\${BLUE}Adding DOCX file to IPFS...\${NC}\"
hnm content add /tmp/sample.docx || echo -e \"\${RED}Failed to add DOCX file\${NC}\"

# Test hnm status
echo -e \"\${YELLOW}Testing hnm status command...\${NC}\"
hnm status || echo -e \"\${RED}Failed to run status command\${NC}\"

# Test hnm content list
echo -e \"\${YELLOW}Testing hnm content list command...\${NC}\"
hnm content list || echo -e \"\${RED}Failed to list content\${NC}\"

# Test hnm keys setup
echo -e \"\${YELLOW}Testing hnm keys setup command...\${NC}\"
echo \"\$API_KEY\" | hnm keys setup || echo -e \"\${RED}Failed to setup API key\${NC}\"

# Test hnm keys list
echo -e \"\${YELLOW}Testing hnm keys list command...\${NC}\"
hnm keys list || echo -e \"\${RED}Failed to list keys\${NC}\"

# Stop IPFS daemon
echo -e \"\${YELLOW}Stopping IPFS daemon...\${NC}\"
hnm stop || echo -e \"\${RED}Failed to stop IPFS daemon\${NC}\"

echo -e \"\${GREEN}Command tests completed!\${NC}\"
EOF"
    
    # Make the script executable
    docker exec $container bash -c "chmod +x /tmp/command-test.sh"
    
    # Run the command test script
    echo -e "${BLUE}Running command test script in container...${NC}"
    docker exec $container bash -c "/tmp/command-test.sh"
    
    echo -e "${GREEN}Command tests completed for $env environment${NC}"
}

# Main function
main() {
    for env in linux wsl mingw macos; do
        run_command_tests $env
    done
    
    echo -e "${GREEN}All command tests completed!${NC}"
}

# Run the main function
main 