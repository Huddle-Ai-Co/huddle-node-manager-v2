#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🚀 Huddle Node Manager - Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Welcome to Huddle Node Manager!${NC}"
echo ""
echo -e "This installer will:"
echo -e "  • Set up the proper directory structure"
echo -e "  • Extract all necessary files"
echo -e "  • Install Python dependencies"
echo -e "  • Configure the HNM system"
echo ""

# Check if we're in the distribution directory
if [ ! -f "install-hnm-complete.sh" ]; then
    echo -e "${RED}❌ Error: This script must be run from the extracted huddle-node-manager-distribution directory${NC}"
    echo -e "${YELLOW}Please extract the downloaded tar.gz file and run this script from within that directory${NC}"
    exit 1
fi

echo -e "${CYAN}📋 Step 1: Initializing distribution structure...${NC}"
if [ -f "scripts/initialize-hnm-distribution.sh" ]; then
    ./scripts/initialize-hnm-distribution.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Distribution structure initialized successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to initialize distribution structure${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Initialize script not found${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}📋 Step 2: Running complete installation...${NC}"
echo -e "${YELLOW}This will install all components and set up the system.${NC}"
echo ""

# Ask user if they want to proceed
read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled. You can run the installer later.${NC}"
    exit 0
fi

# Run the complete installation
echo -e "${BLUE}Running complete installation...${NC}"
cd ~/.huddle-node-manager

# Ensure the install-hnm.sh script is executable
chmod +x install-hnm.sh
chmod +x install-hnm-complete.sh

# Run the complete installation
./install-hnm-complete.sh

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    
    # Verify that hnm command is available
    if command -v hnm >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HNM command is available in PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  HNM command not found in PATH - checking ~/.local/bin${NC}"
        if [ -f "$HOME/.local/bin/hnm" ]; then
            echo -e "${GREEN}✅ HNM command found in ~/.local/bin${NC}"
            echo -e "${YELLOW}💡 You may need to restart your terminal or run: export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        else
            echo -e "${RED}❌ HNM command not found - installation may have failed${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Test the installation: ${BLUE}hnm test dynamic${NC}"
    echo -e "  2. View available commands: ${BLUE}hnm help${NC}"
    echo -e "  3. Run Docker tests: ${BLUE}hnm docker list${NC}"
    echo ""
    echo -e "${YELLOW}💡 The Huddle Node Manager is now ready to use!${NC}"
else
    echo ""
    echo -e "${RED}❌ Installation encountered issues. Please check the output above.${NC}"
    echo -e "${YELLOW}You can try running the installation manually:${NC}"
    echo -e "  ${BLUE}cd ~/.huddle-node-manager && ./install-hnm-complete.sh${NC}"
fi 