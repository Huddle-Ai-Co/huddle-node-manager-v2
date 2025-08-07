#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display header
display_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${GREEN}Huddle Node Manager Installation Test${NC}"
    echo -e "${BLUE}=================================${NC}"
}

# Function to check if HNM is installed
check_hnm_installed() {
    if command -v hnm &> /dev/null; then
        echo -e "${GREEN}✓ HNM is installed and accessible in PATH${NC}"
        echo -e "$(which hnm)"
        return 0
    else
        echo -e "${RED}✗ HNM is not found in PATH${NC}"
        return 1
    fi
}

# Function to check if IPFS is installed
check_ipfs_installed() {
    if command -v ipfs &> /dev/null; then
        echo -e "${GREEN}✓ IPFS is installed and accessible in PATH${NC}"
        echo -e "$(which ipfs)"
        return 0
    else
        echo -e "${RED}✗ IPFS is not found in PATH${NC}"
        return 1
    fi
}

# Function to check HNM commands
test_hnm_commands() {
    echo -e "\n${YELLOW}Testing HNM commands...${NC}"
    
    # Test basic command
    echo -e "\n${BLUE}Testing 'hnm --help'${NC}"
    hnm --help
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 'hnm --help' works correctly${NC}"
    else
        echo -e "${RED}✗ 'hnm --help' failed${NC}"
    fi
    
    # Test status command
    echo -e "\n${BLUE}Testing 'hnm status'${NC}"
    hnm status
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 'hnm status' works correctly${NC}"
    else
        echo -e "${RED}✗ 'hnm status' failed${NC}"
    fi
    
    # Test keys command
    echo -e "\n${BLUE}Testing 'hnm keys --help'${NC}"
    hnm keys --help
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 'hnm keys --help' works correctly${NC}"
    else
        echo -e "${RED}✗ 'hnm keys --help' failed${NC}"
    fi
}

# Function to check installation directories
check_installation_dirs() {
    echo -e "\n${YELLOW}Checking installation directories...${NC}"
    
    # Detect OS
    if [[ "$(uname)" == "Darwin" ]]; then
        OS_TYPE="macOS"
    elif grep -q Microsoft /proc/version 2>/dev/null; then
        OS_TYPE="WSL"
    elif [[ -n "$MSYSTEM" ]]; then
        OS_TYPE="MinGW"
    else
        OS_TYPE="Linux"
    fi
    
    echo -e "${BLUE}Detected environment: ${OS_TYPE}${NC}"
    
    # Check directories based on OS
    case $OS_TYPE in
        "macOS")
            check_dir "/usr/local/bin/hnm"
            check_dir "$HOME/.ipfs"
            check_dir "/usr/local/lib/huddle-node-manager"
            ;;
        "WSL")
            check_dir "$HOME/.local/bin/hnm"
            check_dir "$HOME/.ipfs"
            check_dir "$HOME/.local/lib/huddle-node-manager"
            ;;
        "MinGW")
            check_dir "$HOME/huddle-node-manager/bin/hnm"
            check_dir "$HOME/.ipfs"
            check_dir "$HOME/huddle-node-manager"
            ;;
        "Linux")
            check_dir "/usr/local/bin/hnm"
            check_dir "$HOME/.ipfs"
            check_dir "/usr/local/lib/huddle-node-manager"
            ;;
    esac
}

# Function to check if directory or file exists
check_dir() {
    if [ -e "$1" ]; then
        echo -e "${GREEN}✓ $1 exists${NC}"
    else
        echo -e "${RED}✗ $1 does not exist${NC}"
    fi
}

# Function to run the installation
run_installation() {
    echo -e "\n${YELLOW}Running HNM installation...${NC}"
    
    # Navigate to the huddle-node-manager directory
    cd ~/huddle-node-manager
    
    # Run the installation script
    ./install-hnm.sh
    
    # Check the installation result
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Installation completed successfully${NC}"
    else
        echo -e "${RED}✗ Installation failed${NC}"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    display_header
    
    # Check if HNM is already installed
    if check_hnm_installed; then
        echo -e "${YELLOW}HNM is already installed. Do you want to run tests? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            test_hnm_commands
            check_installation_dirs
        fi
    else
        echo -e "${YELLOW}HNM is not installed. Do you want to install it now? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            if run_installation; then
                # After installation, check again and run tests
                if check_hnm_installed; then
                    test_hnm_commands
                    check_installation_dirs
                fi
            fi
        fi
    fi
    
    # Check IPFS installation
    check_ipfs_installed
    
    echo -e "\n${BLUE}=================================${NC}"
    echo -e "${GREEN}Installation Test Complete${NC}"
    echo -e "${BLUE}=================================${NC}"
}

# Run the main function
main 