#!/bin/bash

# Simple wrapper to run bundled models setup
# Usage: ./setup_models.sh [options]

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🤖 HNM Bundled Models Setup${NC}"
echo -e "${BLUE}Setting up AI models and components for Huddle Node Manager${NC}"
echo ""

# Check if setup_bundled_models.py exists
if [ ! -f "setup_bundled_models.py" ]; then
    echo -e "\033[0;31m❌ setup_bundled_models.py not found${NC}"
    echo "Please run this from the huddle-node-manager directory"
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "\033[0;31m❌ Python 3 is required but not found${NC}"
    exit 1
fi

# Run the Python setup script with all arguments passed through
echo -e "${BLUE}🔄 Running bundled models setup...${NC}"
python3 setup_bundled_models.py "$@"

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Bundled models setup completed!${NC}"
    echo -e "${BLUE}ℹ️  You can now use HNM with full AI capabilities${NC}"
else
    echo ""
    echo -e "\033[0;31m❌ Bundled models setup failed${NC}"
    echo -e "\033[0;33m⚠️  HNM will work but with limited AI functionality${NC}"
    exit 1
fi 