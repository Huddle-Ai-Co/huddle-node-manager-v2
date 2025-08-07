#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager ARM Test Script${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to install IPFS for ARM
install_ipfs_arm() {
    echo -e "${YELLOW}Installing IPFS for ARM architecture...${NC}"
    
    # Create temp directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download ARM version of IPFS
    echo -e "${BLUE}Downloading IPFS for ARM...${NC}"
    curl -L -o ipfs.tar.gz https://dist.ipfs.tech/kubo/v0.35.0/kubo_v0.35.0_linux-arm64.tar.gz
    
    # Extract and install
    echo -e "${BLUE}Extracting IPFS...${NC}"
    tar -xzvf ipfs.tar.gz
    
    echo -e "${BLUE}Installing IPFS...${NC}"
    cd kubo
    chmod +x ipfs
    
    # Copy to appropriate location
    mkdir -p $HOME/bin
    cp ipfs $HOME/bin/
    
    # Add to PATH for current session
    export PATH="$HOME/bin:$PATH"
    
    # Add to .bashrc for future sessions
    echo 'export PATH="$HOME/bin:$PATH"' >> $HOME/.bashrc
    
    # Clean up
    cd $HOME
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}IPFS installed to $HOME/bin/ipfs${NC}"
}

# Function to create a simple HNM script
create_hnm_script() {
    echo -e "${YELLOW}Creating simple HNM script...${NC}"
    
    # Create bin directory if it doesn't exist
    mkdir -p $HOME/bin
    
    # Create a simple HNM script
    cat > $HOME/bin/hnm << 'EOF'
#!/bin/bash

# Simple HNM script for testing

VERSION="0.1.0-test"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "Huddle Node Manager (HNM) - Test Version"
    echo "Usage: hnm [command]"
    echo ""
    echo "Commands:"
    echo "  status      Show IPFS node status"
    echo "  version     Show HNM version"
    echo "  help        Show this help message"
}

# Function to show version
show_version() {
    echo "HNM version $VERSION"
}

# Function to show status
show_status() {
    echo "Checking IPFS status..."
    
    if command -v ipfs &> /dev/null; then
        echo -e "${GREEN}IPFS is installed${NC}"
        echo -e "$(ipfs --version)"
        
        if [ -d "$HOME/.ipfs" ]; then
            echo -e "${GREEN}IPFS repository is initialized${NC}"
        else
            echo -e "${YELLOW}IPFS repository is not initialized${NC}"
        fi
    else
        echo -e "${RED}IPFS is not installed${NC}"
    fi
}

# Main command parser
case "$1" in
    status)
        show_status
        ;;
    version|--version|-v)
        show_version
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0
EOF

    # Make the script executable
    chmod +x $HOME/bin/hnm
    
    # Add to PATH for current session
    export PATH="$HOME/bin:$PATH"
    
    echo -e "${GREEN}HNM script created at $HOME/bin/hnm${NC}"
}

# Function to initialize IPFS
init_ipfs() {
    echo -e "${YELLOW}Initializing IPFS...${NC}"
    
    if command -v ipfs &> /dev/null; then
        echo -e "${BLUE}Running ipfs init...${NC}"
        ipfs init
        
        echo -e "${BLUE}Configuring IPFS...${NC}"
        ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
        ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
        
        echo -e "${GREEN}IPFS initialized and configured!${NC}"
    else
        echo -e "${RED}IPFS is not installed. Cannot initialize.${NC}"
        return 1
    fi
}

# Function to test HNM commands
test_hnm() {
    echo -e "${YELLOW}Testing HNM commands...${NC}"
    
    if command -v hnm &> /dev/null; then
        echo -e "${BLUE}Testing 'hnm --version'${NC}"
        hnm --version
        
        echo -e "${BLUE}Testing 'hnm status'${NC}"
        hnm status
        
        echo -e "${BLUE}Testing 'hnm help'${NC}"
        hnm help
        
        echo -e "${GREEN}HNM commands tested successfully!${NC}"
    else
        echo -e "${RED}HNM is not installed. Cannot test commands.${NC}"
        return 1
    fi
}

# Main function
main() {
    echo -e "${YELLOW}Starting installation and testing...${NC}"
    
    # Install IPFS for ARM
    install_ipfs_arm
    
    # Create HNM script
    create_hnm_script
    
    # Initialize IPFS
    init_ipfs
    
    # Test HNM commands
    test_hnm
    
    echo -e "\n${GREEN}Installation and testing complete!${NC}"
    echo -e "${BLUE}=================================${NC}"
}

# Run the main function
main 