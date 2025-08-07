#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager Installer Update${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to detect environment
detect_environment() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "macOS"
    elif grep -q Microsoft /proc/version 2>/dev/null; then
        echo "WSL"
    elif [[ -n "$MSYSTEM" ]]; then
        echo "MinGW"
    else
        echo "Linux"
    fi
}

# Get current environment
ENVIRONMENT=$(detect_environment)
echo -e "${YELLOW}Detected environment: ${ENVIRONMENT}${NC}"

# Function to update installer
update_installer() {
    local env=$1
    local installer_path="$HOME/huddle-node-manager/install-hnm.sh"
    
    echo -e "\n${YELLOW}Updating installer for $env environment...${NC}"
    
    # Check if installer exists
    if [ ! -f "$installer_path" ]; then
        echo -e "${RED}Error: Installer not found at $installer_path${NC}"
        exit 1
    fi
    
    # Backup original installer
    cp "$installer_path" "${installer_path}.bak"
    echo -e "${BLUE}Created backup at ${installer_path}.bak${NC}"
    
    # Make changes based on environment
    case $env in
        "macOS")
            echo -e "${BLUE}Enhancing macOS support...${NC}"
            # Add macOS-specific changes here
            ;;
        "WSL")
            echo -e "${BLUE}Enhancing WSL support...${NC}"
            # Add WSL-specific changes here
            ;;
        "MinGW")
            echo -e "${BLUE}Enhancing MinGW/Git Bash support...${NC}"
            # Add MinGW-specific changes here
            ;;
        "Linux")
            echo -e "${BLUE}Enhancing Linux support...${NC}"
            # Add Linux-specific changes here
            ;;
    esac
    
    # Make installer executable
    chmod +x "$installer_path"
    echo -e "${GREEN}Updated installer for $env environment${NC}"
}

# Function to test installer
test_installer() {
    local installer_path="$HOME/huddle-node-manager/install-hnm.sh"
    
    echo -e "\n${YELLOW}Testing installer...${NC}"
    
    # Run installer with --help flag
    "$installer_path" --help
    
    # Check if installer has the expected functions
    if grep -q "windows_install" "$installer_path"; then
        echo -e "${GREEN}✓ Windows support found in installer${NC}"
    else
        echo -e "${RED}✗ Windows support not found in installer${NC}"
    fi
    
    if grep -q "macos_install" "$installer_path"; then
        echo -e "${GREEN}✓ macOS support found in installer${NC}"
    else
        echo -e "${RED}✗ macOS support not found in installer${NC}"
    fi
    
    if grep -q "linux_install" "$installer_path"; then
        echo -e "${GREEN}✓ Linux support found in installer${NC}"
    else
        echo -e "${RED}✗ Linux support not found in installer${NC}"
    fi
    
    echo -e "${GREEN}Installer test complete${NC}"
}

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 [options]"
    echo -e ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}update${NC}    Update the installer for the current environment"
    echo -e "  ${GREEN}test${NC}      Test the installer"
    echo -e "  ${GREEN}help${NC}      Show this help message"
}

# Main function
main() {
    case "$1" in
        update)
            update_installer "$ENVIRONMENT"
            ;;
        test)
            test_installer
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run the main function
main "$@" 