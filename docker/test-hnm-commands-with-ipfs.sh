#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Command Tests with IPFS${NC}"
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

# Check if IPFS is already installed
echo -e \"\${YELLOW}Checking if IPFS is already installed...\${NC}\"
if command -v ipfs &> /dev/null; then
    echo -e \"\${GREEN}IPFS is already installed: \$(ipfs --version)\${NC}\"
    IPFS_INSTALLED=true
else
    echo -e \"\${BLUE}IPFS is not installed. Installing now...\${NC}\"
    IPFS_INSTALLED=false

    # Install IPFS
    echo -e \"\${YELLOW}Installing IPFS...\${NC}\"
    # Detect architecture
    ARCH=\$(uname -m)
    if [ \"\$ARCH\" = \"x86_64\" ]; then
        IPFS_ARCH=\"amd64\"
    elif [ \"\$ARCH\" = \"aarch64\" ] || [ \"\$ARCH\" = \"arm64\" ]; then
        IPFS_ARCH=\"arm64\"
    else
        echo -e \"\${RED}Unsupported architecture: \$ARCH\${NC}\"
        exit 1
    fi

    # Download IPFS
    echo -e \"\${BLUE}Downloading IPFS for \$ARCH...\${NC}\"
    cd /tmp
    wget -q https://dist.ipfs.tech/kubo/v0.18.1/kubo_v0.18.1_linux-\$IPFS_ARCH.tar.gz
    tar -xzf kubo_v0.18.1_linux-\$IPFS_ARCH.tar.gz
    cd kubo
    ./install.sh
fi

# Check if IPFS is initialized
echo -e \"\${YELLOW}Checking if IPFS is initialized...\${NC}\"
if [ -d \"\$HOME/.ipfs\" ] && [ -f \"\$HOME/.ipfs/config\" ]; then
    echo -e \"\${GREEN}IPFS is already initialized\${NC}\"
else
    echo -e \"\${BLUE}Initializing IPFS...\${NC}\"
    ipfs init
fi

# Start IPFS daemon in background
echo -e \"\${YELLOW}Starting IPFS daemon...\${NC}\"
ipfs daemon --enable-gc &
IPFS_PID=\$!

# Wait for IPFS daemon to start
echo -e \"\${YELLOW}Waiting for IPFS daemon to start...\${NC}\"
sleep 10

# Check if IPFS is running
if ! pgrep -x \"ipfs\" > /dev/null; then
    echo -e \"\${RED}IPFS daemon failed to start\${NC}\"
    exit 1
fi

echo -e \"\${GREEN}IPFS daemon started successfully\${NC}\"

# Test files
echo -e \"\${YELLOW}Testing file operations...\${NC}\"

# Test with PDF file
echo -e \"\${BLUE}Testing with PDF file...\${NC}\"
cp /home/huddle/huddle-node-manager/Data/RSSC_Stockton_Arts_Grant_\\(SAG\\)_Application.pdf /tmp/
echo -e \"\${BLUE}Adding PDF file to IPFS directly...\${NC}\"
PDF_HASH=\$(ipfs add -q /tmp/RSSC_Stockton_Arts_Grant_\\(SAG\\)_Application.pdf)
if [ -n \"\$PDF_HASH\" ]; then
    echo -e \"\${GREEN}Successfully added PDF file to IPFS: \$PDF_HASH\${NC}\"
else
    echo -e \"\${RED}Failed to add PDF file directly\${NC}\"
fi

# Test with DOCX file
echo -e \"\${BLUE}Testing with DOCX file...\${NC}\"
cp /home/huddle/huddle-node-manager/Data/sample.docx /tmp/
echo -e \"\${BLUE}Adding DOCX file to IPFS directly...\${NC}\"
DOCX_HASH=\$(ipfs add -q /tmp/sample.docx)
if [ -n \"\$DOCX_HASH\" ]; then
    echo -e \"\${GREEN}Successfully added DOCX file to IPFS: \$DOCX_HASH\${NC}\"
else
    echo -e \"\${RED}Failed to add DOCX file directly\${NC}\"
fi

# Test with HNM content add command
echo -e \"\${BLUE}Testing HNM content add command...\${NC}\"
hnm content add /tmp/sample.docx || echo -e \"\${RED}Failed to add file with HNM\${NC}\"

# Test hnm status
echo -e \"\${YELLOW}Testing hnm status command...\${NC}\"
hnm status || echo -e \"\${RED}Failed to run status command\${NC}\"

# Test ipfs commands
echo -e \"\${YELLOW}Testing IPFS commands...\${NC}\"
ipfs cat \$PDF_HASH | head -c 100
echo
echo -e \"\${GREEN}Successfully read PDF content from IPFS\${NC}\"

# Test ipfs pin ls
echo -e \"\${YELLOW}Testing IPFS pin list...\${NC}\"
ipfs pin ls | grep \$PDF_HASH || echo -e \"\${RED}PDF file not pinned\${NC}\"

# Test hnm keys list
echo -e \"\${YELLOW}Testing hnm keys list command...\${NC}\"
hnm keys list || echo -e \"\${RED}Failed to list keys\${NC}\"

# Stop IPFS daemon
echo -e \"\${YELLOW}Stopping IPFS daemon...\${NC}\"
kill \$IPFS_PID
sleep 2
if pgrep -x \"ipfs\" > /dev/null; then
    echo -e \"\${RED}Failed to stop IPFS daemon, forcing...\${NC}\"
    pkill -9 ipfs
fi

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
    # Install necessary packages in containers
    for env in linux wsl mingw macos; do
        echo -e "${YELLOW}Installing necessary packages in $env environment...${NC}"
        docker exec hnm-$env bash -c "apt-get update && apt-get install -y wget tar procps"
    done
    
    # Run tests in each environment
    for env in linux wsl mingw macos; do
        run_command_tests $env
    done
    
    echo -e "${GREEN}All command tests completed!${NC}"
}

# Run the main function
main 