#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set up MinGW/Git Bash environment
export MSYSTEM=MINGW64
export MINGW_PREFIX=/mingw64
export MSYS=winsymlinks:nativestrict
export MINGW_CHOST=x86_64-w64-mingw32

# Create a fake uname command that returns MinGW
cat > /tmp/uname << 'EOF'
#!/bin/bash
if [ "$1" = "-a" ]; then
  echo "MINGW64_NT-10.0-19044 DESKTOP-USER 4.4.0-19041-Microsoft #1237-Microsoft Sat Sep 11 14:32:00 PST 2021 x86_64 x86_64 x86_64 GNU/Linux"
elif [ "$1" = "-s" ]; then
  echo "MINGW64_NT-10.0"
else
  echo "MINGW64_NT-10.0"
fi
EOF
chmod +x /tmp/uname
export PATH="/tmp:$PATH"

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager - MinGW/Git Bash Test Environment${NC}"
echo -e "${BLUE}=================================${NC}"

echo -e "${YELLOW}This container simulates a MinGW/Git Bash environment.${NC}"
echo -e "${YELLOW}You can test the HNM installation by running:${NC}"
echo -e "${GREEN}cd ~/huddle-node-manager && ./install-hnm.sh${NC}"

# Set up environment for API testing
echo -e "\n${BLUE}Setting up environment for API testing:${NC}"
# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"
echo -e "${GREEN}✓ Added ~/.local/bin to PATH${NC}"

# Create API key directory
mkdir -p $HOME/.ipfs/api_keys
echo -e "${GREEN}✓ Created API key directory${NC}"

echo -e "\n${BLUE}Environment Information:${NC}"
echo -e "OS: $(uname -a)"
echo -e "MSYSTEM: $MSYSTEM"
echo -e "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo -e "Current directory: $(pwd)"
echo -e "PATH: $PATH"

# Check if test script exists
if [ -f ~/test-install.sh ]; then
    echo -e "\n${YELLOW}A test script is available. You can run it with:${NC}"
    echo -e "${GREEN}~/test-install.sh${NC}"
fi

echo -e "\n${YELLOW}After installation, you can test the API client with:${NC}"
echo -e "${GREEN}cd ~/huddle-node-manager && python3 -c \"import sys; sys.path.append('.'); from api.apim import client; print('API client loaded successfully')\"${NC}"

# Start bash
exec bash 