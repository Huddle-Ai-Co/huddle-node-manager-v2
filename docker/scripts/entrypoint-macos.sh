#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure directories exist (they should already be created by Dockerfile)
# Only create if they don't exist to avoid permission errors
[ ! -d "/usr/local/bin" ] && mkdir -p /usr/local/bin
[ ! -d "/usr/local/lib" ] && mkdir -p /usr/local/lib
[ ! -d "/usr/local/opt" ] && mkdir -p /usr/local/opt
[ ! -d "/usr/local/Cellar" ] && mkdir -p /usr/local/Cellar
[ ! -d "$HOME/Library/LaunchAgents" ] && mkdir -p $HOME/Library/LaunchAgents

# Create a fake uname command that returns Darwin
cat > /tmp/uname << 'EOF'
#!/bin/bash
if [ "$1" = "-a" ]; then
  echo "Darwin MacBook-Pro.local 21.6.0 Darwin Kernel Version 21.6.0: Mon Aug 22 20:20:05 PDT 2022; root:xnu-8020.140.49~2/RELEASE_X86_64 x86_64"
elif [ "$1" = "-s" ]; then
  echo "Darwin"
else
  echo "Darwin"
fi
EOF
chmod +x /tmp/uname

# Create a fake brew command
cat > /tmp/brew << 'EOF'
#!/bin/bash
if [ "$1" = "install" ] && [ "$2" = "ipfs" ]; then
  echo "==> Installing IPFS"
  mkdir -p /usr/local/Cellar/ipfs/0.17.0
  mkdir -p /usr/local/bin
  
  # Download IPFS binary for Linux (as a substitute)
  echo "==> Downloading IPFS..."
  curl -s -L https://dist.ipfs.tech/kubo/v0.17.0/kubo_v0.17.0_linux-amd64.tar.gz -o /tmp/ipfs.tar.gz
  tar -xzf /tmp/ipfs.tar.gz -C /tmp
  cp /tmp/kubo/ipfs /usr/local/bin/
  chmod +x /usr/local/bin/ipfs
  
  echo "==> IPFS installed to /usr/local/bin/ipfs"
elif [ "$1" = "--version" ]; then
  echo "Homebrew 4.0.28"
else
  echo "Usage: brew COMMAND [options]"
  echo "brew install FORMULA|CASK"
  echo "brew uninstall FORMULA|CASK"
  echo "brew update"
  echo "brew list"
fi
EOF
chmod +x /tmp/brew

# Create a fake open command
cat > /tmp/open << 'EOF'
#!/bin/bash
echo "Opening $* (simulated)"
EOF
chmod +x /tmp/open

# Add our fake commands to PATH
export PATH="/tmp:$PATH"

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Huddle Node Manager - macOS Test Environment${NC}"
echo -e "${BLUE}=================================${NC}"

echo -e "${YELLOW}This container simulates a macOS environment.${NC}"
echo -e "${YELLOW}You can test the HNM installation by running:${NC}"
echo -e "${GREEN}cd ~/huddle-node-manager && ./install-hnm.sh${NC}"

# Set up environment for API testing
echo -e "\n${BLUE}Setting up environment for API testing:${NC}"
# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"
echo -e "${GREEN}✓ Added ~/.local/bin to PATH${NC}"

# Create API key directory
mkdir -p ~/.config/huddle-node-manager
echo -e "${GREEN}✓ Created API key directory${NC}"

# Set up production directory structure for Docker
echo -e "\n${BLUE}Setting up production directory structure:${NC}"
mkdir -p ~/.huddle-node-manager/bundled_models
mkdir -p ~/.huddle-node-manager/config
mkdir -p ~/.huddle-node-manager/logs
mkdir -p ~/.huddle-node-manager/cache
echo -e "${GREEN}✓ Created production directory structure: ~/.huddle-node-manager${NC}"

# Set environment variable for Docker containers
export HNM_PRODUCTION_PATH="$HOME/.huddle-node-manager"
echo -e "${GREEN}✓ Set HNM_PRODUCTION_PATH=$HNM_PRODUCTION_PATH${NC}"

# Environment Information
echo -e "\n${BLUE}Environment Information:${NC}"
echo "OS: $(uname -a)"
echo "Brew: $(brew --version 2>/dev/null || echo 'Not installed')"
echo "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo "Current directory: $(pwd)"
echo "PATH: $PATH"

echo -e "\n${YELLOW}A test script is available. You can run it with:${NC}"
echo -e "${GREEN}~/test-install.sh${NC}"

echo -e "\n${YELLOW}After installation, you can test the API client with:${NC}"
echo -e "${GREEN}cd ~/huddle-node-manager && python3 -c \"import sys; sys.path.append('.'); from api.apim import client; print('API client loaded successfully')\"${NC}"

# Start bash shell
exec /bin/bash 