#!/bin/bash

# HuddleAI IPFS Node Setup Script
# This script helps users set up their own persistent IPFS node
# Can be run standalone or called by install-hnm.sh

# Detect if being called by install-hnm.sh (modular mode)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ -n "$HNM_INSTALLER_MODE" ]]; then
    MODULAR_MODE=true
else
    MODULAR_MODE=false
fi

# Define logging functions (use parent's if in modular mode, otherwise define our own)
if [[ "$MODULAR_MODE" = true ]] && declare -f log_info >/dev/null 2>&1; then
    # Use parent script's logging functions
    :
else
    # Define our own logging functions for standalone mode
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    log_info() {
        echo -e "${BLUE}ℹ️  $1${NC}"
    }

    log_success() {
        echo -e "${GREEN}✅ $1${NC}"
    }

    log_warning() {
        echo -e "${YELLOW}⚠️  $1${NC}"
    }

    log_error() {
        echo -e "${RED}❌ $1${NC}"
    }

    log_step() {
        echo -e "${CYAN}🔄 $1${NC}"
    }
fi

# Check for help flag (only in standalone mode)
if [[ "$MODULAR_MODE" = false ]] && [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "HuddleAI IPFS Node Setup Tool"
    echo "---------------------------"
    echo "This tool helps you set up a persistent IPFS node on your computer."
    echo ""
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "This script will:"
    echo "  - Install IPFS if not already installed"
    echo "  - Initialize the IPFS repository"
    echo "  - Configure the node for persistent operation"
    echo "  - Set up automatic startup on system boot"
    echo "  - Create helper tools for managing content"
    echo ""
    exit 0
fi

# Display welcome banner (only in standalone mode)
if [[ "$MODULAR_MODE" = false ]]; then
    echo "=================================================="
    echo "    Welcome to the HuddleAI IPFS Node Setup Tool  "
    echo "=================================================="
    echo ""
    echo "This tool by HuddleAI Co. will help you set up your IPFS node"
    echo "so you can persistently host content on IPFS"
    echo "without relying on paid services."
    echo ""
fi

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "Mac";;
        CYGWIN*|MINGW*) echo "Windows";;
        *)          echo "UNKNOWN";;
    esac
}

# Check IPFS installation status
check_ipfs_status() {
    if command -v ipfs &> /dev/null; then
        local version=$(ipfs --version | cut -d' ' -f3)
        local repo_init="false"
        local daemon_running="false"
        
        if [ -d "$HOME/.ipfs" ]; then
            repo_init="true"
        fi
        
        if ipfs swarm peers &>/dev/null; then
            daemon_running="true"
        fi
        
        echo "installed|$version|$repo_init|$daemon_running"
    else
        echo "none|||"
    fi
}

# Install IPFS based on operating system
install_ipfs() {
    local system="$1"
    
    log_step "Installing IPFS for $system..."
    
    if [ "$system" = "Mac" ]; then
        # Check if Homebrew is installed
        if command -v brew &> /dev/null; then
            log_success "Homebrew is installed."
        else
            log_step "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            log_success "Homebrew installed!"
        fi
        
        log_step "Installing IPFS with Homebrew..."
        brew install ipfs
        
        # Ensure IPFS is linked and available
        if ! command -v ipfs &> /dev/null; then
            log_step "Linking IPFS binary..."
            brew link ipfs --force
            
            # Update PATH for current session
            export PATH="/usr/local/bin:$PATH"
            
            # Verify IPFS is now available
            if ! command -v ipfs &> /dev/null; then
                log_error "IPFS installation failed - binary not found after linking"
                return 1
            fi
        fi
        
        log_success "IPFS installed and linked!"
        
    elif [ "$system" = "Linux" ]; then
        # Download the latest version
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        
        log_step "Downloading IPFS..."
        if command -v curl &> /dev/null; then
            curl -O https://dist.ipfs.tech/kubo/v0.35.0/kubo_v0.35.0_linux-amd64.tar.gz
        elif command -v wget &> /dev/null; then
            wget https://dist.ipfs.tech/kubo/v0.35.0/kubo_v0.35.0_linux-amd64.tar.gz
        else
            log_error "Neither curl nor wget found. Cannot download IPFS."
            return 1
        fi
        
        tar -xvzf kubo_v0.35.0_linux-amd64.tar.gz
        
        log_step "Installing IPFS..."
        cd kubo
        sudo bash install.sh
        
        # Clean up
        cd "$HOME"
        rm -rf "$TMP_DIR"
        
        log_success "IPFS installed!"
        
    elif [ "$system" = "Windows" ]; then
        log_warning "For Windows, we recommend downloading and installing IPFS Desktop from:"
        echo "https://docs.ipfs.tech/install/ipfs-desktop/"
        echo ""
        log_info "After installation, come back and run this script again to continue setup."
        return 1
    else
        log_error "Unsupported operating system: $system"
        log_info "Please visit https://docs.ipfs.tech/install/command-line/ for manual installation instructions."
        return 1
    fi
    
    return 0
}

# Initialize IPFS repository
initialize_ipfs() {
    # Ensure IPFS is in PATH
    export PATH="/usr/local/bin:$PATH"
    
    if [ ! -d "$HOME/.ipfs" ]; then
        log_step "Initializing IPFS repository..."
        if command -v ipfs &> /dev/null; then
            ipfs init
            log_success "IPFS repository initialized!"
        else
            log_error "IPFS command not found - installation may have failed"
            return 1
        fi
    else
        log_success "IPFS repository already initialized."
    fi
    return 0
}

# Configure IPFS for optimal performance
configure_ipfs() {
    # Ensure IPFS is in PATH
    export PATH="/usr/local/bin:$PATH"
    
    log_step "Configuring IPFS node for optimal performance..."
    
    if command -v ipfs &> /dev/null; then
        # Increase storage limit (100GB instead of default 10GB)
        ipfs config Datastore.StorageMax 100GB
        
        # Enable garbage collection
        ipfs config --json Datastore.GCPeriod '"12h"'
        
        # Configure gateway to listen on all interfaces
        ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
        
        log_success "IPFS configuration updated!"
    else
        log_error "IPFS command not found - skipping configuration"
        return 1
    fi
    return 0
}

# Setup IPFS daemon service
setup_ipfs_service() {
    local system="$1"
    
    log_step "Setting up IPFS as a background service..."
    
    if [ "$system" = "Linux" ]; then
        # Create systemd service file
        SERVICE_FILE="/tmp/ipfs.service"
        cat > "$SERVICE_FILE" << EOL
[Unit]
Description=IPFS Daemon
After=network.target

[Service]
ExecStart=$(which ipfs) daemon
Restart=always
User=$(whoami)
Environment="IPFS_PATH=$HOME/.ipfs"

[Install]
WantedBy=multi-user.target
EOL
        
        # Install service
        sudo mv "$SERVICE_FILE" /etc/systemd/system/ipfs.service
        sudo systemctl daemon-reload
        sudo systemctl enable ipfs
        sudo systemctl start ipfs
        
        log_success "IPFS service installed and started!"
        log_info "Check status with: systemctl status ipfs"

    elif [ "$system" = "Mac" ]; then
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENT_DIR"
        
        PLIST_FILE="$LAUNCH_AGENT_DIR/io.ipfs.daemon.plist"
        cat > "$PLIST_FILE" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.ipfs.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which ipfs)</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>IPFS_PATH</key>
        <string>$HOME/.ipfs</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/.ipfs/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.ipfs/logs/stderr.log</string>
</dict>
</plist>
EOL
        
        # Create logs directory
        mkdir -p "$HOME/.ipfs/logs"
        
        # Load the agent
        launchctl load "$PLIST_FILE"
        
        log_success "IPFS LaunchAgent installed and started!"
        log_info "Your IPFS node will now start automatically when you log in"
    fi
    
    return 0
}

# Modern HNM integration info
create_ipfs_helper() {
    log_step "IPFS setup completed for modern HNM integration..."
    
    log_success "IPFS node is ready for HNM (Huddle Node Manager)"
    
    if [[ "$MODULAR_MODE" = false ]]; then
        echo ""
        log_info "🚀 Next Steps:"
        echo "  1. Install HNM: ./install-hnm.sh"
        echo "  2. Start your node: hnm start"
        echo "  3. Add content: hnm content add my-file.txt"
        echo "  4. Check status: hnm status"
        echo ""
        log_info "💡 HNM provides all the functionality you need:"
        echo "  - hnm content add [file]  # Add content to IPFS"
        echo "  - hnm content list       # List pinned content"
        echo "  - hnm status             # Check node status"
        echo "  - hnm webui              # Open web interface"
    fi
    
    return 0
}

# Main IPFS setup function
setup_ipfs_node() {
    log_step "Starting comprehensive IPFS node setup..."
    
    local system=$(detect_os)
    log_info "Detected operating system: $system"
    
    local ipfs_status=$(check_ipfs_status)
    IFS='|' read -r status version repo_init daemon_running <<< "$ipfs_status"
    
    # Install IPFS if needed
    if [ "$status" = "none" ]; then
        if ! install_ipfs "$system"; then
            return 1
        fi
    else
        log_success "IPFS is already installed (version: $version)"
    fi
    
    # Initialize repository if needed
    if ! initialize_ipfs; then
        return 1
    fi
    
    # Configure IPFS
    if ! configure_ipfs; then
        return 1
    fi
    
    # Setup service
    if ! setup_ipfs_service "$system"; then
        return 1
    fi
    
    # Create helper script
    if ! create_ipfs_helper; then
        return 1
    fi
    
    log_success "🎉 Comprehensive IPFS setup completed!"
    return 0
}

# Show final instructions (only in standalone mode)
show_completion_message() {
    echo ""
    echo "=================================================="
    echo "        🎉 HuddleAI Setup Complete! 🎉            "
    echo "=================================================="
    echo ""
    echo "Your HuddleAI IPFS node is now set up and configured to run automatically."
    echo ""
    echo "Useful commands:"
    echo "  - hnm content add [file]  - Add and pin content"
    echo "  - hnm status             - Check node status"
    echo "  - hnm content list       - List pinned content"
    echo ""
    echo "Your content will be available via:"
    echo "  - Local gateway: http://localhost:8080/ipfs/[hash]"
    echo "  - Public gateway: https://ipfs.io/ipfs/[hash]"
    echo ""
    echo "To share content with others, just share the content hash (CID)."
    echo "Anyone with the hash can access the content as long as at least"
    echo "one node on the network (like yours) continues to pin it."
    echo ""
    echo "Thank you for using HuddleAI's decentralized storage solution! 🚀"
}

# Main execution (only run if not in modular mode or if explicitly called)
if [[ "$MODULAR_MODE" = false ]]; then
    # Standalone mode - run the full setup
    if setup_ipfs_node; then
        show_completion_message
        exit 0
    else
        log_error "IPFS setup failed!"
        exit 1
    fi
fi

# If we reach here, we're in modular mode - functions are now available for import 