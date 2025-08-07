#!/bin/bash

# HNM (Huddle Node Manager) Installer
# Installs HNM command system-wide for easy access
# Provides backward compatibility with original Huddle IPFS Node Manager commands
# Includes optional comprehensive IPFS node setup

set -e

# Get the directory where this script is located (for finding source files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If script is symlinked, get the real path
if [ -L "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}")")" && pwd)"
fi

# For distribution installations, source files are in the original distribution directory
# This handles the case where the script is copied to ~/.huddle-node-manager/
# but source files are in the original distribution directory

# Try to find the original distribution directory
POSSIBLE_PATHS=(
    "/Users/tangj4/Downloads/huddle-node-manager/huddle-node-manager-distribution"
    "$HOME/Downloads/huddle-node-manager/huddle-node-manager-distribution"
    "$(pwd)/../huddle-node-manager-distribution"
    "$SCRIPT_DIR/../huddle-node-manager-distribution"
    "$SCRIPT_DIR"
)

SOURCE_DIR=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path/docker" ] && [ -d "$path/docs" ] && [ -d "$path/scripts" ]; then
        SOURCE_DIR="$path"
        break
    fi
done

if [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR="$SCRIPT_DIR"  # Fallback to script directory
fi

# Debug: Show what directory we're using for source files
echo "🔍 Looking for source files in: $SOURCE_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if running as root
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. This will install HNM system-wide."
        return 0
    else
        log_info "Installing HNM for current user only."
        return 1
    fi
}

# Check and install cross-platform system dependencies
setup_system_dependencies() {
    log_info "🌐 Detecting system and installing dependencies..."
    
    # Change to home directory first
    cd "$HOME"
    
    # Try cross-platform installer first - look in multiple locations
    SETUP_SCRIPT=""
    for path in "$HOME/.local/lib/huddle-node-manager" "$HOME/Downloads/huddle-node-manager" "$(pwd)" "$SCRIPT_DIR" "$SCRIPT_DIR/scripts"; do
        if [ -f "$path/setup_system_dependencies.py" ]; then
            SETUP_SCRIPT="$path/setup_system_dependencies.py"
            break
        fi
    done
    
    if [ -n "$SETUP_SCRIPT" ]; then
        log_step "Running cross-platform system dependency installer..."
        python3 "$SETUP_SCRIPT"
        
        if [ $? -eq 0 ]; then
            log_success "System dependencies installed"
            
            # Source appropriate environment script
            if [[ "$(uname)" == "Darwin" ]] && [ -f "macos_environment_setup.sh" ]; then
                log_info "Loading macOS environment..."
                source macos_environment_setup.sh
            elif [[ "$(uname)" == "Linux" ]] && [ -f "linux_environment_setup.sh" ]; then
                log_info "Loading Linux environment..."
                source linux_environment_setup.sh
            fi
        else
            log_warning "Cross-platform system setup had issues, trying OS-specific fallback..."
            
            # Fallback to OS-specific installers
            if [[ "$(uname)" == "Darwin" ]] && [ -n "$SETUP_SCRIPT" ]; then
                log_step "Falling back to macOS-specific installer..."
                python3 "$SETUP_SCRIPT"
            fi
        fi
    else
        log_warning "Cross-platform system installer not found"
        
        # Fallback to OS-specific installers
        if [[ "$(uname)" == "Darwin" ]] && [ -n "$SETUP_SCRIPT" ]; then
            log_step "Using macOS-specific installer..."
            python3 "$SETUP_SCRIPT"
        else
            log_info "Manual system dependency installation may be required:"
            echo "  • Install your OS package manager (Homebrew, apt, yum, etc.)"
            echo "  • Install: cmake git python3 ffmpeg tesseract"
        fi
    fi
    
    echo ""
}

# Detect operating system
detect_os() {
    OS="$(uname -s)"
    case "${OS}" in
        Linux*)     SYSTEM=Linux;;
        Darwin*)    SYSTEM=Mac;;
        CYGWIN*|MINGW*) SYSTEM=Windows;;
        *)          SYSTEM="UNKNOWN";;
    esac
    echo "$SYSTEM"
}

# Check IPFS installation status
check_ipfs_status() {
    local status="none"
    local version=""
    local repo_initialized=false
    local daemon_running=false
    
    if command -v ipfs &> /dev/null; then
        status="installed"
        version=$(ipfs --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        
        if [ -d "$HOME/.ipfs" ]; then
            repo_initialized=true
        fi
        
        if ipfs swarm peers &>/dev/null; then
            daemon_running=true
        fi
    fi
    
    echo "$status|$version|$repo_initialized|$daemon_running"
}

# ======================================================================
# Helper function for bundled models setup

setup_bundled_models_interactive() {
    # Setup bundled models and AI components
    # Check for setup script in current directory or local lib scripts directory
    SETUP_SCRIPT=""
    if [ -f "setup_bundled_models.py" ]; then
        SETUP_SCRIPT="setup_bundled_models.py"
    elif [ -f "../.local/lib/huddle-node-manager/scripts/setup_bundled_models.py" ]; then
        SETUP_SCRIPT="../.local/lib/huddle-node-manager/scripts/setup_bundled_models.py"
    fi
    
    if [ -n "$SETUP_SCRIPT" ]; then
        log_step "Setting up AI models and components..."
        echo ""
        log_info "🤖 AI Model Setup Options:"
        echo "  1) Download all models (~2-5GB) - Complete AI functionality"
        echo "  2) Skip large models (~50MB) - Basic functionality only"
        echo "  3) Skip model setup entirely"
        echo ""
        echo -n "Choose option (1-3) [1]: "
        read -r model_choice
        
        case "${model_choice:-1}" in
            1)
                # Use virtual environment's Python if available
                if [ -f "run_in_venv.sh" ]; then
                    ./run_in_venv.sh python3 "$SETUP_SCRIPT" --download-models
                else
                    python3 "$SETUP_SCRIPT" --download-models
                fi
                ;;
            2)
                # Use virtual environment's Python if available
                if [ -f "run_in_venv.sh" ]; then
                    ./run_in_venv.sh python3 "$SETUP_SCRIPT" --skip-large-models
                else
                    python3 "$SETUP_SCRIPT" --skip-large-models
                fi
                ;;
            3)
                log_info "Skipping model setup - you can run 'source hnm_env/bin/activate && python3 setup_bundled_models.py' later"
                ;;
            *)
                log_warning "Invalid choice, defaulting to complete model download"
                # Use virtual environment's Python if available
                if [ -f "run_in_venv.sh" ]; then
                    ./run_in_venv.sh python3 "$SETUP_SCRIPT" --download-models
                else
                    python3 "$SETUP_SCRIPT" --download-models
                fi
                ;;
        esac
    else
        log_warning "setup_bundled_models.py not found - skipping AI model setup"
        log_info "To setup AI models later, run: python3 setup_bundled_models.py or python3 ../.local/lib/huddle-node-manager/scripts/setup_bundled_models.py"
    fi
}

# ======================================================================
# IPFS functions moved to modular setup-ipfs-node.sh for DRY architecture

setup_ipfs_node() {
    log_step "Starting comprehensive IPFS node setup..."
    
    # Set environment variable to indicate modular mode
    export HNM_INSTALLER_MODE=true
    
    # Check if setup-ipfs-node.sh exists
    if [ ! -f "./setup-ipfs-node.sh" ]; then
        log_error "setup-ipfs-node.sh not found in current directory"
        log_info "Please ensure setup-ipfs-node.sh is in the same directory as this installer"
        return 1
    fi
    
    # Make sure it's executable
    chmod +x "./setup-ipfs-node.sh"
    
    # Call the external script with environment variable set
    if HNM_INSTALLER_MODE=true bash -c 'source "./setup-ipfs-node.sh" && setup_ipfs_node'; then
        log_success "🎉 Comprehensive IPFS setup completed!"
        return 0
    else
        log_error "IPFS setup failed"
        return 1
    fi
}

# Create legacy command symlinks
create_legacy_symlinks() {
    local install_dir="$1"
    local hnm_path="$2"
    
    log_step "Creating backward compatibility symlinks..."
    
    # Create symlinks for original Huddle IPFS Node Manager commands
    if [ "$install_dir" = "system" ]; then
        # System-wide installation
        ln -sf "$hnm_path" "/usr/local/bin/ipfs-setup"
        ln -sf "$hnm_path" "/usr/local/bin/ipfs-manager"
        ln -sf "$hnm_path" "/usr/local/bin/ipfs-manager-version"
        ln -sf "$hnm_path" "/usr/local/bin/ipfs-manager-uninstall"
        
        log_success "Created system-wide legacy command symlinks:"
        log_info "  ipfs-setup → hnm"
        log_info "  ipfs-manager → hnm"
        log_info "  ipfs-manager-version → hnm"
        log_info "  ipfs-manager-uninstall → hnm"
    else
        # User installation
        ln -sf "$hnm_path" "$HOME/.local/bin/ipfs-setup"
        ln -sf "$hnm_path" "$HOME/.local/bin/ipfs-manager"
        ln -sf "$hnm_path" "$HOME/.local/bin/ipfs-manager-version"
        ln -sf "$hnm_path" "$HOME/.local/bin/ipfs-manager-uninstall"
        
        log_success "Created user legacy command symlinks:"
        log_info "  ipfs-setup → hnm"
        log_info "  ipfs-manager → hnm"
        log_info "  ipfs-manager-version → hnm"
        log_info "  ipfs-manager-uninstall → hnm"
    fi
}

# Remove legacy symlinks
remove_legacy_symlinks() {
    local install_dir="$1"
    
    if [ "$install_dir" = "system" ]; then
        # System-wide removal
        sudo rm -f "/usr/local/bin/ipfs-setup"
        sudo rm -f "/usr/local/bin/ipfs-manager"
        sudo rm -f "/usr/local/bin/ipfs-manager-version"
        sudo rm -f "/usr/local/bin/ipfs-manager-uninstall"
    else
        # User removal
        rm -f "$HOME/.local/bin/ipfs-setup"
        rm -f "$HOME/.local/bin/ipfs-manager"
        rm -f "$HOME/.local/bin/ipfs-manager-version"
        rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
    fi
    
    log_info "Removed legacy command symlinks"
}

# Create production directory structure
create_production_structure() {
    log_step "Creating production directory structure..."
    
    # Create main production directory
    PROD_DIR="$HOME/.huddle-node-manager"
    mkdir -p "$PROD_DIR"
    
    # Create subdirectories
    mkdir -p "$PROD_DIR/bundled_models"
    mkdir -p "$PROD_DIR/config"
    mkdir -p "$PROD_DIR/logs"
    mkdir -p "$PROD_DIR/cache"
    
    log_success "Production directory structure created: $PROD_DIR"
    
    # Set permissions
    chmod 755 "$PROD_DIR"
    chmod 755 "$PROD_DIR/bundled_models"
    
    log_info "Production installation will use: $PROD_DIR"
}

# System-wide installation function
system_install() {
    log_step "Installing HNM system-wide..."
    
    # Create necessary directories
    mkdir -p /usr/local/lib/huddle-node-manager
    mkdir -p /usr/local/share/doc/huddle-node-manager
    mkdir -p /etc/huddle-node-manager
    mkdir -p /usr/local/lib/huddle-node-manager/api
    mkdir -p /usr/local/lib/huddle-node-manager/models
    mkdir -p /usr/local/lib/huddle-node-manager/scripts
    
    # Install main executable
    cp hnm /usr/local/bin/hnm
    chmod +x /usr/local/bin/hnm
    
    # Install library scripts
    cp ipfs-*-manager.sh /usr/local/lib/huddle-node-manager/
    cp open-ipfs-webui.sh /usr/local/lib/huddle-node-manager/
    cp api_key_manager.sh /usr/local/lib/huddle-node-manager/
    chmod +x /usr/local/lib/huddle-node-manager/*.sh
    

    
    # Install API components (new production structure)
    log_step "Installing API components..."
    
    # Install Python dependencies with device optimization (always run for production)
    if command -v pip3 &> /dev/null; then
        log_info "Installing Python dependencies with hardware optimization..."
        
        # Setup macOS system dependencies FIRST (before models)
        setup_system_dependencies
        
        # Check and upgrade Python AFTER system dependencies are installed
        check_and_upgrade_python
        
        # Check if HNM script is executable
        if [ ! -x "hnm" ]; then
            chmod +x hnm
            log_info "Made HNM script executable"
        fi
        
        # Test the HNM script
        if ! ./hnm --version >/dev/null 2>&1; then
            log_error "HNM script test failed"
            exit 1
        fi
        
        log_success "HNM script test passed"
        
        # Skip IPFS setup if this is system-install-only mode
        if [ "$SYSTEM_INSTALL_ONLY" = "false" ]; then
            # Check IPFS status
            local ipfs_status=$(check_ipfs_status)
            IFS='|' read -r status version repo_init daemon_running <<< "$ipfs_status"
            
            echo ""
            log_info "🔍 IPFS Status Check:"
            if [ "$status" = "installed" ]; then
                log_success "IPFS is installed (version: $version)"
                if [ "$repo_init" = "true" ]; then
                    log_success "IPFS repository is initialized"
                else
                    log_warning "IPFS repository needs initialization"
                fi
                if [ "$daemon_running" = "true" ]; then
                    log_success "IPFS daemon is running"
                else
                    log_warning "IPFS daemon is not running"
                fi
            else
                log_warning "IPFS is not installed"
            fi
            
            # Ask user about IPFS setup
            echo ""
            log_info "🚀 Setup Options:"
            echo "  1) Install HNM only (skip IPFS setup)"
            echo "  2) Install HNM + comprehensive IPFS setup (recommended)"
            echo "  3) Comprehensive IPFS setup only (skip HNM)"
            echo ""
            echo -n "Choose option (1-3): "
            read -r setup_choice
            
            case "$setup_choice" in
                1)
                    log_info "Installing HNM only..."
                    ;;
                2)
                    log_info "Installing HNM + comprehensive IPFS setup..."
                    if ! setup_ipfs_node; then
                        log_error "IPFS setup failed. Continuing with HNM installation only."
                    fi
                    ;;
                3)
                    log_info "Running comprehensive IPFS setup only..."
                    setup_ipfs_node
                    log_success "🎉 IPFS setup completed!"
                    echo ""
                    log_info "To install HNM later, run this script again and choose option 1."
                    exit 0
                    ;;
                *)
                    log_error "Invalid choice. Defaulting to HNM only installation."
                    ;;
            esac
            
            # Check for existing original installation
            if command -v ipfs-setup >/dev/null 2>&1 || command -v ipfs-manager >/dev/null 2>&1; then
                log_warning "Existing Huddle IPFS Node Manager installation detected"
                log_info "HNM will provide backward compatibility with your existing commands"
                echo ""
            fi
        else
            log_info "Running in system-install-only mode (IPFS setup already completed)"
        fi
        
        # Create production directory structure
        create_production_structure
        
        # Setup bundled models and AI components AFTER system dependencies
        log_step "Setting up AI models and components..."
        setup_bundled_models_interactive
        
        # Create virtual environment for Python dependencies
        log_step "Creating virtual environment..."
        if [ ! -d "hnm_env" ]; then
            # Use the best available Python (Homebrew Python 3.11 if available)
            if command -v /opt/homebrew/bin/python3.11 &> /dev/null; then
                /opt/homebrew/bin/python3.11 -m venv hnm_env
                log_success "Virtual environment created with Python 3.11: hnm_env"
            else
                python3 -m venv hnm_env
                log_success "Virtual environment created: hnm_env"
            fi
        else
            log_info "Virtual environment already exists: hnm_env"
        fi
        
        # Activate virtual environment
        log_step "Activating virtual environment..."
        source hnm_env/bin/activate
        log_success "Virtual environment activated"
        
        # Verify we're using the virtual environment's Python
        log_step "Verifying virtual environment..."
        if [ "$VIRTUAL_ENV" = "$(pwd)/hnm_env" ]; then
            log_success "Virtual environment active: $(which python3)"
        else
            log_warning "Virtual environment not properly activated"
        fi
        
        # Run our comprehensive dependency setup
        SETUP_DEPS_SCRIPT=""
        for path in "$HOME/.local/lib/huddle-node-manager" "$HOME/Downloads/huddle-node-manager" "$(pwd)" "$SCRIPT_DIR"; do
            if [ -f "$path/setup_dependencies.py" ]; then
                SETUP_DEPS_SCRIPT="$path/setup_dependencies.py"
                break
            fi
        done
        
        if [ -n "$SETUP_DEPS_SCRIPT" ]; then
            log_step "Running device-agnostic dependency installer..."
            python3 "$SETUP_DEPS_SCRIPT"
            if [ $? -eq 0 ]; then
                log_success "Python dependencies installed with device optimizations"
            else
                log_warning "Optimized installation failed, falling back to standard installation"
                # Fallback to standard installation
                if [ -f "requirements.txt" ]; then
                    pip3 install -r requirements.txt
                    log_success "Python dependencies installed (standard)"
                fi
            fi
        else
            log_warning "setup_dependencies.py not found, using standard installation"
            if [ -f "requirements.txt" ]; then
                pip3 install -r requirements.txt
                log_success "Python dependencies installed from requirements.txt"
            fi
        fi
        
        # Verify installation automatically
        log_step "Verifying installation..."
        if [ -f "verify_installation.py" ]; then
            python3 verify_installation.py
        fi
    else
        log_warning "pip3 not found - skipping Python dependencies"
        log_info "To install API dependencies manually, run: python3 setup_dependencies.py"
    fi
    
    # Copy API components if they exist (for backward compatibility)
    if [ -d "api" ]; then
        cp -r api/* "$HOME/.local/lib/huddle-node-manager/api/"
        log_success "API components installed (legacy)"
    else
        log_info "API components not found (using new production structure)"
    fi
    
    # Install models
    log_step "Installing ML models..."
    if [ -d "$SOURCE_DIR/models" ]; then
        cp -r "$SOURCE_DIR/models"/* /usr/local/lib/huddle-node-manager/models/
        log_success "ML models installed"
    else
        log_warning "Models directory not found - skipping models installation"
    fi
    
    # Install scripts
    log_step "Installing utility scripts..."
    if [ -d "$SOURCE_DIR/scripts" ]; then
        cp -r "$SOURCE_DIR/scripts"/* /usr/local/lib/huddle-node-manager/scripts/
        # Make Python scripts executable
        find /usr/local/lib/huddle-node-manager/scripts -name "*.py" -exec chmod +x {} \;
        log_success "Utility scripts installed"
    else
        log_warning "Scripts directory not found - skipping scripts installation"
    fi
    
    # Install important Python files from root directory
    log_step "Installing core Python modules..."
    # Copy important Python files that are needed by the servers
    if [ -f "$SOURCE_DIR/vllm_style_optimizer.py" ]; then
        cp "$SOURCE_DIR/vllm_style_optimizer.py" /usr/local/lib/huddle-node-manager/
    else
        log_warning "vllm_style_optimizer.py not found"
    fi
    if [ -f "$SOURCE_DIR/platform_adaptive_config.py" ]; then
        cp "$SOURCE_DIR/platform_adaptive_config.py" /usr/local/lib/huddle-node-manager/
    else
        log_warning "platform_adaptive_config.py not found"
    fi
    if [ -f "$SOURCE_DIR/resource_monitor.py" ]; then
        cp "$SOURCE_DIR/resource_monitor.py" /usr/local/lib/huddle-node-manager/
    else
        log_warning "resource_monitor.py not found"
    fi
    if [ -f "$SOURCE_DIR/device_detection_test.py" ]; then
        cp "$SOURCE_DIR/device_detection_test.py" /usr/local/lib/huddle-node-manager/
    else
        log_warning "device_detection_test.py not found"
    fi
    chmod +x /usr/local/lib/huddle-node-manager/*.py 2>/dev/null || true
    log_success "Core Python modules installed"
    
    # Install Docker infrastructure
    log_step "Installing Docker testing infrastructure..."
    if [ -d "$SOURCE_DIR/docker" ]; then
        mkdir -p /usr/local/lib/huddle-node-manager/docker
        cp -r "$SOURCE_DIR/docker"/* /usr/local/lib/huddle-node-manager/docker/
        chmod +x /usr/local/lib/huddle-node-manager/docker/*.sh 2>/dev/null || true
        log_success "Docker infrastructure installed"
    else
        log_warning "Docker directory not found - skipping Docker infrastructure"
    fi
    
    # Testing scripts are now handled by the initialization script
    log_step "Testing scripts installation..."
    log_info "Testing scripts are handled by the initialization script"
    log_success "Testing scripts installation (handled by initialization)"
    
    # Install comprehensive documentation
    log_step "Installing documentation..."
    if [ -f "$SOURCE_DIR/README.md" ]; then
        cp "$SOURCE_DIR/README.md" /usr/local/share/doc/huddle-node-manager/
    fi
    if [ -f "$SOURCE_DIR/SHAREABLE_LINK.md" ]; then
        cp "$SOURCE_DIR/SHAREABLE_LINK.md" /usr/local/share/doc/huddle-node-manager/
    fi
    if [ -d "$SOURCE_DIR/docs" ]; then
        cp -r "$SOURCE_DIR/docs"/* /usr/local/share/doc/huddle-node-manager/
        log_success "Comprehensive documentation installed"
    else
        log_warning "Docs directory not found - skipping detailed documentation"
    fi
    
    # Create backward compatibility symlinks
    ln -sf /usr/local/bin/hnm /usr/local/bin/ipfs-setup
    ln -sf /usr/local/bin/hnm /usr/local/bin/ipfs-manager
    ln -sf /usr/local/bin/hnm /usr/local/bin/ipfs-manager-version
    ln -sf /usr/local/bin/hnm /usr/local/bin/ipfs-manager-uninstall
    
    log_success "HNM installed system-wide"
    log_info "You can now use 'hnm' from anywhere in your terminal"
    log_info "Original commands (ipfs-setup, ipfs-manager, etc.) also work!"
}

# User-level installation function
user_install() {
    log_step "Installing HNM for current user..."
    
    # Create necessary directories
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/lib/huddle-node-manager"
    mkdir -p "$HOME/.local/share/doc/huddle-node-manager"
    mkdir -p "$HOME/.config/huddle-node-manager"
    mkdir -p "$HOME/.local/lib/huddle-node-manager/api"
    mkdir -p "$HOME/.local/lib/huddle-node-manager/models"
    mkdir -p "$HOME/.local/lib/huddle-node-manager/scripts"
    
    # Update PATH if needed
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        log_warning "Your PATH does not include ~/.local/bin"
        log_info "Adding ~/.local/bin to your PATH in ~/.bashrc and ~/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        
        # Check if zshrc exists and update it too
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        fi
        
        log_info "Please restart your terminal or run: source ~/.bashrc"
    fi
    
    # Install main executable
    cp hnm "$HOME/.local/bin/hnm"
    chmod +x "$HOME/.local/bin/hnm"
    
    # Install library scripts
    cp ipfs-*-manager.sh "$HOME/.local/lib/huddle-node-manager/"
    cp open-ipfs-webui.sh "$HOME/.local/lib/huddle-node-manager/"
    cp api_key_manager.sh "$HOME/.local/lib/huddle-node-manager/"
    chmod +x "$HOME/.local/lib/huddle-node-manager/"*.sh
    

    
    # Install API components (new production structure)
    log_step "Installing API components..."
    
    # Install Python dependencies with device optimization (always run for production)
    if command -v pip3 &> /dev/null; then
        log_info "Installing Python dependencies with hardware optimization..."
        
        # Setup macOS system dependencies FIRST (before models)
        setup_system_dependencies
        
        # Check for existing or active virtual environment
        log_step "Checking for existing virtual environment..."
        
        # Check if we're already in a virtual environment
        if [ -n "$VIRTUAL_ENV" ]; then
            log_success "Already in virtual environment: $VIRTUAL_ENV"
            if [ "$VIRTUAL_ENV" = "$(pwd)/hnm_env" ]; then
                log_success "Using existing HNM virtual environment"
            else
                log_warning "Different virtual environment active: $VIRTUAL_ENV"
                log_info "Will create HNM-specific environment"
            fi
        fi
        
        # Check for existing hnm_env directory
        if [ -d "hnm_env" ]; then
            log_success "HNM virtual environment already exists: hnm_env"
            log_info "Using existing environment"
        else
            log_step "Creating new virtual environment..."
            # Use the best available Python (Homebrew Python 3.11 if available)
            if command -v /opt/homebrew/bin/python3.11 &> /dev/null; then
                /opt/homebrew/bin/python3.11 -m venv hnm_env
                log_success "Virtual environment created with Python 3.11: hnm_env"
            else
                python3 -m venv hnm_env
                log_success "Virtual environment created: hnm_env"
            fi
        fi
        
        # Activate virtual environment
        log_step "Activating virtual environment..."
        source hnm_env/bin/activate
        log_success "Virtual environment activated"
        
        # Verify we're using the virtual environment's Python
        log_step "Verifying virtual environment..."
        if [ "$VIRTUAL_ENV" = "$(pwd)/hnm_env" ]; then
            log_success "Virtual environment active: $(which python3)"
        else
            log_warning "Virtual environment not properly activated"
        fi
        
        # Setup bundled models and AI components AFTER system dependencies
        log_step "Setting up AI models and components..."
        setup_bundled_models_interactive
        
        # Run our comprehensive dependency setup
        # Check for setup script in current directory or local lib scripts directory
        SETUP_DEPS_SCRIPT=""
        if [ -f "setup_dependencies.py" ]; then
            SETUP_DEPS_SCRIPT="setup_dependencies.py"
        elif [ -f "../.local/lib/huddle-node-manager/scripts/setup_dependencies.py" ]; then
            SETUP_DEPS_SCRIPT="../.local/lib/huddle-node-manager/scripts/setup_dependencies.py"
        fi
        
        if [ -n "$SETUP_DEPS_SCRIPT" ]; then
            log_step "Running device-agnostic dependency installer..."
            python3 "$SETUP_DEPS_SCRIPT"
            if [ $? -eq 0 ]; then
                log_success "Python dependencies installed with device optimizations"
            else
                log_warning "Optimized installation failed, falling back to standard installation"
                # Fallback to standard installation
                if [ -f "requirements.txt" ]; then
                    pip3 install -r requirements.txt
                    log_success "Python dependencies installed (standard)"
                fi
            fi
        else
            log_warning "setup_dependencies.py not found, using standard installation"
            if [ -f "requirements.txt" ]; then
                pip3 install -r requirements.txt
                log_success "Python dependencies installed from requirements.txt"
            fi
        fi
        
        # Verify installation automatically
        log_step "Verifying installation..."
        if [ -f "verify_installation.py" ]; then
            python3 verify_installation.py
        fi
    else
        log_warning "pip3 not found - skipping Python dependencies"
        log_info "To install API dependencies manually, run: python3 setup_dependencies.py"
    fi
    
    # Copy API components if they exist (for backward compatibility)
    if [ -d "$SOURCE_DIR/api" ]; then
        cp -r "$SOURCE_DIR/api"/* "$HOME/.local/lib/huddle-node-manager/api/"
        log_success "API components installed (legacy)"
    else
        log_info "API components not found (using new production structure)"
    fi
    
    # Install models
    log_step "Installing ML models..."
    if [ -d "$SOURCE_DIR/models" ]; then
        cp -r "$SOURCE_DIR/models"/* "$HOME/.local/lib/huddle-node-manager/models/"
        log_success "ML models installed"
    else
        log_warning "Models directory not found - skipping models installation"
    fi
    
    # Install scripts
    log_step "Installing utility scripts..."
    if [ -d "$SOURCE_DIR/scripts" ]; then
        cp -r "$SOURCE_DIR/scripts"/* "$HOME/.local/lib/huddle-node-manager/scripts/"
        # Make Python scripts executable
        find "$HOME/.local/lib/huddle-node-manager/scripts" -name "*.py" -exec chmod +x {} \;
        log_success "Utility scripts installed"
    else
        log_warning "Scripts directory not found - skipping scripts installation"
    fi
    
    # Install important Python files from root directory
    log_step "Installing core Python modules..."
    # Copy important Python files that are needed by the servers
    if [ -f "$SOURCE_DIR/vllm_style_optimizer.py" ]; then
        cp "$SOURCE_DIR/vllm_style_optimizer.py" "$HOME/.local/lib/huddle-node-manager/"
    else
        log_warning "vllm_style_optimizer.py not found"
    fi
    if [ -f "$SOURCE_DIR/platform_adaptive_config.py" ]; then
        cp "$SOURCE_DIR/platform_adaptive_config.py" "$HOME/.local/lib/huddle-node-manager/"
    else
        log_warning "platform_adaptive_config.py not found"
    fi
    if [ -f "$SOURCE_DIR/resource_monitor.py" ]; then
        cp "$SOURCE_DIR/resource_monitor.py" "$HOME/.local/lib/huddle-node-manager/"
    else
        log_warning "resource_monitor.py not found"
    fi
    if [ -f "$SOURCE_DIR/device_detection_test.py" ]; then
        cp "$SOURCE_DIR/device_detection_test.py" "$HOME/.local/lib/huddle-node-manager/"
    else
        log_warning "device_detection_test.py not found"
    fi
    chmod +x "$HOME/.local/lib/huddle-node-manager/"*.py 2>/dev/null || true
    log_success "Core Python modules installed"
    
    # Install Docker infrastructure
    log_step "Installing Docker testing infrastructure..."
    if [ -d "$SOURCE_DIR/docker" ]; then
        mkdir -p "$HOME/.local/lib/huddle-node-manager/docker"
        cp -r "$SOURCE_DIR/docker"/* "$HOME/.local/lib/huddle-node-manager/docker/"
        chmod +x "$HOME/.local/lib/huddle-node-manager/docker/"*.sh 2>/dev/null || true
        log_success "Docker infrastructure installed"
    else
        log_warning "Docker directory not found - skipping Docker infrastructure"
    fi
    
    # Testing scripts are now handled by the initialization script
    log_step "Testing scripts installation..."
    log_info "Testing scripts are handled by the initialization script"
    log_success "Testing scripts installation (handled by initialization)"
    
    # Install comprehensive documentation
    log_step "Installing documentation..."
    if [ -f "$SOURCE_DIR/README.md" ]; then
        cp "$SOURCE_DIR/README.md" "$HOME/.local/share/doc/huddle-node-manager/"
    fi
    if [ -f "$SOURCE_DIR/SHAREABLE_LINK.md" ]; then
        cp "$SOURCE_DIR/SHAREABLE_LINK.md" "$HOME/.local/share/doc/huddle-node-manager/"
    fi
    if [ -d "$SOURCE_DIR/docs" ]; then
        cp -r "$SOURCE_DIR/docs"/* "$HOME/.local/share/doc/huddle-node-manager/"
        log_success "Comprehensive documentation installed"
    else
        log_warning "Docs directory not found - skipping detailed documentation"
    fi
    
    # Update the hnm script to point to the user's library directory
    sed -i.bak "s|HNM_LIB_DIR=\"/usr/local/lib/huddle-node-manager\"|HNM_LIB_DIR=\"$HOME/.local/lib/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
    sed -i.bak "s|HNM_DOC_DIR=\"/usr/local/share/doc/huddle-node-manager\"|HNM_DOC_DIR=\"$HOME/.local/share/doc/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
    sed -i.bak "s|HNM_CONFIG_DIR=\"/etc/huddle-node-manager\"|HNM_CONFIG_DIR=\"$HOME/.config/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
    
    # Create backward compatibility symlinks
    ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-setup"
    ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager"
    ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager-version"
    ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager-uninstall"
    
    log_success "HNM installed for current user"
    log_info "You can now use 'hnm' from your terminal"
    log_info "Original commands (ipfs-setup, ipfs-manager, etc.) also work!"
}

# Windows-specific installation function
windows_install() {
    log_step "Installing HNM for Windows..."
    
    # Determine if we're in WSL or native Windows
    local in_wsl=false
    if grep -q Microsoft /proc/version 2>/dev/null; then
        in_wsl=true
        log_info "Windows Subsystem for Linux (WSL) detected."
    else
        log_info "Native Windows environment detected."
    fi
    
    # Create necessary directories
    if [ "$in_wsl" = "true" ]; then
        # WSL installation - similar to Linux
        mkdir -p "$HOME/.local/bin"
        mkdir -p "$HOME/.local/lib/huddle-node-manager"
        mkdir -p "$HOME/.local/share/doc/huddle-node-manager"
        mkdir -p "$HOME/.config/huddle-node-manager"
        mkdir -p "$HOME/.local/lib/huddle-node-manager/api"
        mkdir -p "$HOME/.local/lib/huddle-node-manager/models"
        mkdir -p "$HOME/.local/lib/huddle-node-manager/scripts"
        
        # Install main executable
        cp hnm "$HOME/.local/bin/hnm"
        chmod +x "$HOME/.local/bin/hnm"
        
        # Create Windows batch file wrapper
        cat > "$HOME/.local/bin/hnm.bat" << EOL
@echo off
wsl ~/.local/bin/hnm %*
EOL
        
        # Update PATH if needed
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            log_warning "Your PATH does not include ~/.local/bin"
            log_info "Adding ~/.local/bin to your PATH in ~/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        fi
    else
        # Native Windows installation
        mkdir -p "$HOME/huddle-node-manager/bin"
        mkdir -p "$HOME/huddle-node-manager/lib"
        mkdir -p "$HOME/huddle-node-manager/docs"
        mkdir -p "$HOME/huddle-node-manager/config"
        mkdir -p "$HOME/huddle-node-manager/lib/api"
        mkdir -p "$HOME/huddle-node-manager/lib/models"
        mkdir -p "$HOME/huddle-node-manager/lib/scripts"
        
        # Install main executable and create batch file
        cp hnm "$HOME/huddle-node-manager/bin/hnm"
        chmod +x "$HOME/huddle-node-manager/bin/hnm"
        
        # Create Windows batch file wrapper
        cat > "$HOME/huddle-node-manager/bin/hnm.bat" << EOL
@echo off
bash "%~dp0\hnm" %*
EOL
        
        # Create shortcut for Windows PATH
        log_info "Adding installation directory to your PATH..."
        echo 'export PATH="$HOME/huddle-node-manager/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    
    # Install library scripts
    if [ "$in_wsl" = "true" ]; then
        cp ipfs-*-manager.sh "$HOME/.local/lib/huddle-node-manager/"
        cp open-ipfs-webui.sh "$HOME/.local/lib/huddle-node-manager/"
        cp api_key_manager.sh "$HOME/.local/lib/huddle-node-manager/"
        chmod +x "$HOME/.local/lib/huddle-node-manager/"*.sh
    else
        cp ipfs-*-manager.sh "$HOME/huddle-node-manager/lib/"
        cp open-ipfs-webui.sh "$HOME/huddle-node-manager/lib/"
        cp api_key_manager.sh "$HOME/huddle-node-manager/lib/"
        chmod +x "$HOME/huddle-node-manager/lib/"*.sh
    fi
    

    
    # Install API components
    log_step "Installing API components..."
    if [ -d "api" ]; then
        if [ "$in_wsl" = "true" ]; then
            cp -r api/* "$HOME/.local/lib/huddle-node-manager/api/"
        else
            cp -r api/* "$HOME/huddle-node-manager/lib/api/"
        fi
        
        # Install Python dependencies with device optimization
        if command -v pip3 &> /dev/null; then
            log_info "Installing Python dependencies with hardware optimization..."
            
            # Setup macOS system dependencies FIRST (before models)
            setup_system_dependencies
            
            # Setup bundled models and AI components AFTER system dependencies
            log_step "Setting up AI models and components..."
            setup_bundled_models_interactive
            
            # Run our comprehensive dependency setup
            if [ -f "setup_dependencies.py" ]; then
                log_step "Running device-agnostic dependency installer..."
                python3 setup_dependencies.py
                if [ $? -eq 0 ]; then
                    log_success "Python dependencies installed with device optimizations"
                else
                    log_warning "Optimized installation failed, falling back to standard installation"
                    # Fallback to standard installation
                    if [ -f "requirements.txt" ]; then
                        pip3 install -r requirements.txt
                        log_success "Python dependencies installed (standard)"
                    fi
                fi
            else
                log_warning "setup_dependencies.py not found, using standard installation"
                if [ -f "requirements.txt" ]; then
                    pip3 install -r requirements.txt
                    log_success "Python dependencies installed from requirements.txt"
                fi
            fi
            
            # Run API setup script
            if [ "$in_wsl" = "true" ] && [ -f "$HOME/.local/lib/huddle-node-manager/api/apim/setup.py" ]; then
                chmod +x "$HOME/.local/lib/huddle-node-manager/api/apim/setup.py"
                log_info "Running API setup script..."
                python3 "$HOME/.local/lib/huddle-node-manager/api/apim/setup.py"
            elif [ "$in_wsl" = "false" ] && [ -f "$HOME/huddle-node-manager/lib/api/apim/setup.py" ]; then
                chmod +x "$HOME/huddle-node-manager/lib/api/apim/setup.py"
                log_info "Running API setup script..."
                python3 "$HOME/huddle-node-manager/lib/api/apim/setup.py"
            fi
            
            # Verify installation automatically
            log_step "Verifying installation..."
            if [ -f "verify_installation.py" ]; then
                python3 verify_installation.py
            fi
        else
            log_warning "pip3 not found - skipping Python dependencies"
            log_info "To install API dependencies manually, run: python3 setup_dependencies.py"
        fi
    else
        log_warning "API directory not found - skipping API installation"
    fi
    
    # Install models
    log_step "Installing ML models..."
    if [ -d "bundled_models" ]; then
        if [ "$in_wsl" = "true" ]; then
            cp -r bundled_models/* "$HOME/.local/lib/huddle-node-manager/models/"
        else
            cp -r bundled_models/* "$HOME/huddle-node-manager/lib/models/"
        fi
        log_success "ML models installed"
    else
        log_warning "Models directory not found - skipping models installation"
    fi
    
    # Install scripts
    log_step "Installing utility scripts..."
    if [ -d "scripts" ]; then
        if [ "$in_wsl" = "true" ]; then
            cp -r scripts/* "$HOME/.local/lib/huddle-node-manager/scripts/"
            find "$HOME/.local/lib/huddle-node-manager/scripts" -name "*.py" -exec chmod +x {} \;
        else
            cp -r scripts/* "$HOME/huddle-node-manager/lib/scripts/"
            find "$HOME/huddle-node-manager/lib/scripts" -name "*.py" -exec chmod +x {} \;
        fi
        log_success "Utility scripts installed"
    else
        log_warning "Scripts directory not found - skipping scripts installation"
    fi
    
    # Install important Python files from local lib directory
    log_step "Installing core Python modules..."
    if [ "$in_wsl" = "true" ]; then
        # Copy important Python files that are needed by the servers
        cp ../.local/lib/huddle-node-manager/vllm_style_optimizer.py "$HOME/.local/lib/huddle-node-manager/" 2>/dev/null || log_warning "vllm_style_optimizer.py not found"
        cp ../.local/lib/huddle-node-manager/platform_adaptive_config.py "$HOME/.local/lib/huddle-node-manager/" 2>/dev/null || log_warning "platform_adaptive_config.py not found"
        cp ../.local/lib/huddle-node-manager/resource_monitor.py "$HOME/.local/lib/huddle-node-manager/" 2>/dev/null || log_warning "resource_monitor.py not found"
        cp ../.local/lib/huddle-node-manager/device_detection_test.py "$HOME/.local/lib/huddle-node-manager/" 2>/dev/null || log_warning "device_detection_test.py not found"
        chmod +x "$HOME/.local/lib/huddle-node-manager/"*.py 2>/dev/null || true
    else
        # Copy important Python files that are needed by the servers
        cp vllm_style_optimizer.py "$HOME/huddle-node-manager/lib/" 2>/dev/null || log_warning "vllm_style_optimizer.py not found"
        cp platform_adaptive_config.py "$HOME/huddle-node-manager/lib/" 2>/dev/null || log_warning "platform_adaptive_config.py not found"
        cp resource_monitor.py "$HOME/huddle-node-manager/lib/" 2>/dev/null || log_warning "resource_monitor.py not found"
        cp device_detection_test.py "$HOME/huddle-node-manager/lib/" 2>/dev/null || log_warning "device_detection_test.py not found"
        chmod +x "$HOME/huddle-node-manager/lib/"*.py 2>/dev/null || true
    fi
    log_success "Core Python modules installed"
    
    # Install comprehensive documentation
    log_step "Installing documentation..."
    if [ "$in_wsl" = "true" ]; then
        cp README.md SHAREABLE_LINK.md "$HOME/.local/share/doc/huddle-node-manager/"
        if [ -d "docs" ]; then
            cp -r docs/* "$HOME/.local/share/doc/huddle-node-manager/"
        fi
    else
        cp README.md SHAREABLE_LINK.md "$HOME/huddle-node-manager/docs/"
        if [ -d "docs" ]; then
            cp -r docs/* "$HOME/huddle-node-manager/docs/"
        fi
    fi
    log_success "Documentation installed"
    
    # Update the hnm script to point to the correct library directory
    if [ "$in_wsl" = "true" ]; then
        sed -i.bak "s|HNM_LIB_DIR=\"/usr/local/lib/huddle-node-manager\"|HNM_LIB_DIR=\"$HOME/.local/lib/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
        sed -i.bak "s|HNM_DOC_DIR=\"/usr/local/share/doc/huddle-node-manager\"|HNM_DOC_DIR=\"$HOME/.local/share/doc/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
        sed -i.bak "s|HNM_CONFIG_DIR=\"/etc/huddle-node-manager\"|HNM_CONFIG_DIR=\"$HOME/.config/huddle-node-manager\"|" "$HOME/.local/bin/hnm"
        
        # Create backward compatibility symlinks
        ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-setup"
        ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager"
        ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager-version"
        ln -sf "$HOME/.local/bin/hnm" "$HOME/.local/bin/ipfs-manager-uninstall"
    else
        sed -i.bak "s|HNM_LIB_DIR=\"/usr/local/lib/huddle-node-manager\"|HNM_LIB_DIR=\"$HOME/huddle-node-manager/lib\"|" "$HOME/huddle-node-manager/bin/hnm"
        sed -i.bak "s|HNM_DOC_DIR=\"/usr/local/share/doc/huddle-node-manager\"|HNM_DOC_DIR=\"$HOME/huddle-node-manager/docs\"|" "$HOME/huddle-node-manager/bin/hnm"
        sed -i.bak "s|HNM_CONFIG_DIR=\"/etc/huddle-node-manager\"|HNM_CONFIG_DIR=\"$HOME/huddle-node-manager/config\"|" "$HOME/huddle-node-manager/bin/hnm"
        
        # Create batch files for backward compatibility
        cat > "$HOME/huddle-node-manager/bin/ipfs-setup.bat" << EOL
@echo off
bash "%~dp0\hnm" %*
EOL
        cat > "$HOME/huddle-node-manager/bin/ipfs-manager.bat" << EOL
@echo off
bash "%~dp0\hnm" %*
EOL
        cat > "$HOME/huddle-node-manager/bin/ipfs-manager-version.bat" << EOL
@echo off
bash "%~dp0\hnm" --version %*
EOL
        cat > "$HOME/huddle-node-manager/bin/ipfs-manager-uninstall.bat" << EOL
@echo off
bash "%~dp0\hnm" --uninstall %*
EOL
    fi
    
    log_success "HNM installed for Windows"
    if [ "$in_wsl" = "true" ]; then
        log_info "You can now use 'hnm' from your WSL terminal"
    else
        log_info "You can now use 'hnm.bat' from your Windows terminal"
        log_info "Or 'hnm' from Git Bash/MINGW"
    fi
    log_info "Original commands (ipfs-setup, ipfs-manager, etc.) also work!"
}

# Uninstall HNM
uninstall_hnm() {
    log_warning "This will remove HNM configuration and files"
    
    # Detect existing installations
    local system_installed=false
    local user_installed=false
    local windows_installed=false
    local wsl_installed=false
    
    if [ -f "/usr/local/bin/hnm" ]; then
        system_installed=true
    fi
    if [ -f "$HOME/.local/bin/hnm" ]; then
        user_installed=true
    fi
    if [ -f "$HOME/huddle-node-manager/bin/hnm" ]; then
        windows_installed=true
    fi
    if grep -q Microsoft /proc/version 2>/dev/null && [ -f "$HOME/.local/bin/hnm" ]; then
        wsl_installed=true
    fi
    
    if [ "$system_installed" = "false" ] && [ "$user_installed" = "false" ] && [ "$windows_installed" = "false" ] && [ "$wsl_installed" = "false" ]; then
        log_error "HNM not found. Nothing to uninstall."
        return 1
    fi
    
    # Show uninstall options
    echo ""
    log_info "🗑️  Uninstall Options:"
    
    if [ "$windows_installed" = "true" ] || [ "$wsl_installed" = "true" ]; then
        echo "  1) Remove Windows/WSL installation"
        echo "  2) Remove everything including IPFS setup"
        echo "  3) Cancel uninstall"
        echo ""
        
        read -p "Choose option (1-3): " uninstall_option
        
        case "$uninstall_option" in
            1)
                log_step "Removing Windows/WSL HNM installation..."
                
                if [ "$windows_installed" = "true" ]; then
                    # Native Windows installation
                    rm -rf "$HOME/huddle-node-manager"
                    log_success "Windows installation removed"
                fi
                
                if [ "$wsl_installed" = "true" ]; then
                    # WSL installation
                    rm -f "$HOME/.local/bin/hnm"
                    rm -f "$HOME/.local/bin/hnm.bat"
                    rm -f "$HOME/.local/bin/ipfs-setup"
                    rm -f "$HOME/.local/bin/ipfs-manager"
                    rm -f "$HOME/.local/bin/ipfs-manager-version"
                    rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
                    rm -rf "$HOME/.local/lib/huddle-node-manager"
                    rm -rf "$HOME/.local/share/doc/huddle-node-manager"
                    rm -rf "$HOME/.config/huddle-node-manager"
                    rm -rf "$HOME/.hnm"
                    log_success "WSL installation removed"
                fi
                ;;
            2)
                log_step "Removing everything including IPFS setup..."
                
                if [ "$windows_installed" = "true" ]; then
                    # Native Windows installation
                    rm -rf "$HOME/huddle-node-manager"
                    log_success "Windows installation removed"
                fi
                
                if [ "$wsl_installed" = "true" ]; then
                    # WSL installation
                    rm -f "$HOME/.local/bin/hnm"
                    rm -f "$HOME/.local/bin/hnm.bat"
                    rm -f "$HOME/.local/bin/ipfs-setup"
                    rm -f "$HOME/.local/bin/ipfs-manager"
                    rm -f "$HOME/.local/bin/ipfs-manager-version"
                    rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
                    rm -rf "$HOME/.local/lib/huddle-node-manager"
                    rm -rf "$HOME/.local/share/doc/huddle-node-manager"
                    rm -rf "$HOME/.config/huddle-node-manager"
                    rm -rf "$HOME/.hnm"
                    log_success "WSL installation removed"
                fi
                
                # Stop IPFS daemon if running
                if command -v ipfs &> /dev/null; then
                    log_step "Stopping IPFS daemon..."
                    ipfs shutdown || true
                fi
                
                # Ask if user wants to remove IPFS data
                read -p "Remove IPFS repository data? This will delete all your IPFS data! (y/N): " remove_ipfs_data
                if [ "$remove_ipfs_data" = "y" ] || [ "$remove_ipfs_data" = "Y" ]; then
                    log_warning "Removing IPFS repository data..."
                    rm -rf "$HOME/.ipfs"
                    log_success "IPFS repository data removed"
                fi
                
                # Ask if user wants to remove IPFS binary
                read -p "Remove IPFS binary? (y/N): " remove_ipfs_binary
                if [ "$remove_ipfs_binary" = "y" ] || [ "$remove_ipfs_binary" = "Y" ]; then
                    if [ "$windows_installed" = "true" ]; then
                        log_warning "Removing IPFS binary..."
                        rm -rf "$HOME/ipfs-bin"
                        log_success "IPFS binary removed"
                    fi
                fi
                
                # Ask if user wants to remove Python packages installed by API
                read -p "Remove Python packages installed by HNM API? (y/N): " remove_python_packages
                if [ "$remove_python_packages" = "y" ] || [ "$remove_python_packages" = "Y" ]; then
                    if command -v pip3 &> /dev/null; then
                        log_warning "Removing Python packages..."
                        pip3 uninstall -y requests pathlib || true
                        log_success "Python packages removed"
                    else
                        log_warning "pip3 not found - cannot remove Python packages"
                    fi
                fi
                
                log_success "Complete uninstall finished"
                ;;
            3)
                log_info "Uninstall cancelled"
                return 0
                ;;
            *)
                log_error "Invalid option"
                return 1
                ;;
        esac
    else
        # Standard Linux/macOS uninstall options
        echo "  1) Remove user installation only"
        echo "  2) Remove system-wide installation (requires sudo)"
        echo "  3) Remove both user and system installations"
        echo "  4) Remove everything including IPFS setup"
        echo "  5) Cancel uninstall"
        echo ""
        
        read -p "Choose option (1-5): " uninstall_option
        
        case "$uninstall_option" in
            1)
                if [ "$user_installed" = "true" ]; then
                    log_step "Removing user HNM installation..."
                    # Remove executables and symlinks
                    rm -f "$HOME/.local/bin/hnm"
                    rm -f "$HOME/.local/bin/ipfs-setup"
                    rm -f "$HOME/.local/bin/ipfs-manager"
                    rm -f "$HOME/.local/bin/ipfs-manager-version"
                    rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
                    
                    # Remove library files, including API components, models, and scripts
                    rm -rf "$HOME/.local/lib/huddle-node-manager"
                    
                    # Remove documentation
                    rm -rf "$HOME/.local/share/doc/huddle-node-manager"
                    
                    # Remove configuration
                    rm -rf "$HOME/.config/huddle-node-manager"
                    rm -rf "$HOME/.hnm"
                    
                    log_success "User installation removed"
                else
                    log_warning "No user installation found"
                fi
                ;;
            2)
                if [ "$system_installed" = "true" ]; then
                    log_step "Removing system-wide HNM installation..."
                    
                    # Remove main executable
                    sudo rm -f /usr/local/bin/hnm
                    
                    # Remove legacy symlinks
                    sudo rm -f /usr/local/bin/ipfs-setup
                    sudo rm -f /usr/local/bin/ipfs-manager
                    sudo rm -f /usr/local/bin/ipfs-manager-version
                    sudo rm -f /usr/local/bin/ipfs-manager-uninstall
                    
                    # Remove library files, including API components, models, and scripts
                    sudo rm -rf /usr/local/lib/huddle-node-manager
                    
                    # Remove documentation
                    sudo rm -rf /usr/local/share/doc/huddle-node-manager
                    
                    # Remove configuration
                    sudo rm -rf /etc/huddle-node-manager
                    
                    log_info "Removed legacy command symlinks"
                    log_success "System-wide installation removed"
                else
                    log_warning "No system-wide installation found"
                fi
                ;;
            3)
                log_step "Removing all HNM installations..."
                
                # Remove user installation
                if [ "$user_installed" = "true" ]; then
                    # Remove executables and symlinks
                    rm -f "$HOME/.local/bin/hnm"
                    rm -f "$HOME/.local/bin/ipfs-setup"
                    rm -f "$HOME/.local/bin/ipfs-manager"
                    rm -f "$HOME/.local/bin/ipfs-manager-version"
                    rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
                    
                    # Remove library files, including API components, models, and scripts
                    rm -rf "$HOME/.local/lib/huddle-node-manager"
                    
                    # Remove documentation
                    rm -rf "$HOME/.local/share/doc/huddle-node-manager"
                    
                    # Remove configuration
                    rm -rf "$HOME/.config/huddle-node-manager"
                    rm -rf "$HOME/.hnm"
                    
                    log_info "Removed user installation"
                fi
                
                # Remove system installation
                if [ "$system_installed" = "true" ]; then
                    # Remove main executable
                    sudo rm -f /usr/local/bin/hnm
                    
                    # Remove legacy symlinks
                    sudo rm -f /usr/local/bin/ipfs-setup
                    sudo rm -f /usr/local/bin/ipfs-manager
                    sudo rm -f /usr/local/bin/ipfs-manager-version
                    sudo rm -f /usr/local/bin/ipfs-manager-uninstall
                    
                    # Remove library files, including API components, models, and scripts
                    sudo rm -rf /usr/local/lib/huddle-node-manager
                    
                    # Remove documentation
                    sudo rm -rf /usr/local/share/doc/huddle-node-manager
                    
                    # Remove configuration
                    sudo rm -rf /etc/huddle-node-manager
                    
                    log_info "Removed system-wide installation"
                fi
                
                log_success "All HNM installations removed"
                ;;
            4)
                log_step "Removing everything including IPFS setup..."
                
                # Remove user installation
                if [ "$user_installed" = "true" ]; then
                    # Remove executables and symlinks
                    rm -f "$HOME/.local/bin/hnm"
                    rm -f "$HOME/.local/bin/ipfs-setup"
                    rm -f "$HOME/.local/bin/ipfs-manager"
                    rm -f "$HOME/.local/bin/ipfs-manager-version"
                    rm -f "$HOME/.local/bin/ipfs-manager-uninstall"
                    
                    # Remove library files, including API components, models, and scripts
                    rm -rf "$HOME/.local/lib/huddle-node-manager"
                    
                    # Remove documentation
                    rm -rf "$HOME/.local/share/doc/huddle-node-manager"
                    
                    # Remove configuration
                    rm -rf "$HOME/.config/huddle-node-manager"
                    rm -rf "$HOME/.hnm"
                fi
                
                # Remove system installation
                if [ "$system_installed" = "true" ]; then
                    # Remove main executable
                    sudo rm -f /usr/local/bin/hnm
                    
                    # Remove legacy symlinks
                    sudo rm -f /usr/local/bin/ipfs-setup
                    sudo rm -f /usr/local/bin/ipfs-manager
                    sudo rm -f /usr/local/bin/ipfs-manager-version
                    sudo rm -f /usr/local/bin/ipfs-manager-uninstall
                    
                    # Remove library files, including API components, models, and scripts
                    sudo rm -rf /usr/local/lib/huddle-node-manager
                    
                    # Remove documentation
                    sudo rm -rf /usr/local/share/doc/huddle-node-manager
                    
                    # Remove configuration
                    sudo rm -rf /etc/huddle-node-manager
                fi
                
                # Stop IPFS daemon if running
                if command -v ipfs &> /dev/null; then
                    log_step "Stopping IPFS daemon..."
                    ipfs shutdown || true
                fi
                
                # Ask if user wants to remove IPFS data
                read -p "Remove IPFS repository data? This will delete all your IPFS data! (y/N): " remove_ipfs_data
                if [ "$remove_ipfs_data" = "y" ] || [ "$remove_ipfs_data" = "Y" ]; then
                    log_warning "Removing IPFS repository data..."
                    rm -rf "$HOME/.ipfs"
                    log_success "IPFS repository data removed"
                fi
                
                # Ask if user wants to remove Python packages installed by API
                read -p "Remove Python packages installed by HNM API? (y/N): " remove_python_packages
                if [ "$remove_python_packages" = "y" ] || [ "$remove_python_packages" = "Y" ]; then
                    if command -v pip3 &> /dev/null; then
                        log_warning "Removing Python packages..."
                        pip3 uninstall -y requests pathlib || true
                        log_success "Python packages removed"
                    else
                        log_warning "pip3 not found - cannot remove Python packages"
                    fi
                fi
                
                log_success "Complete uninstall finished"
                ;;
            5)
                log_info "Uninstall cancelled"
                return 0
                ;;
            *)
                log_error "Invalid option"
                return 1
                ;;
        esac
    fi
    
    log_success "🎉 Uninstall completed!"
}

# Reinstall function
reinstall_hnm() {
    log_step "Reinstalling Huddle Node Manager (HNM)..."
    
    echo ""
    log_info "🔄 Reinstall Options:"
    echo "  1) Clean reinstall (remove existing, then install fresh)"
    echo "  2) Upgrade in place (keep settings, update binaries)"
    echo "  3) Cancel reinstall"
    echo ""
    echo -n "Choose option (1-3): "
    read -r reinstall_choice
    
    case "$reinstall_choice" in
        1)
            log_info "Performing clean reinstall..."
            uninstall_hnm
            if [ $? -eq 0 ]; then
                log_step "Starting fresh installation..."
                main "--fresh-install"
            fi
            ;;
        2)
            log_info "Upgrading in place..."
            # Just run the installation again - it will overwrite files
            main "--upgrade"
            ;;
        3)
            log_info "Reinstall cancelled"
            return 0
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
}

# Main installer function
main() {
    # Check for special flags
    local SYSTEM_INSTALL_ONLY=false
    local FRESH_INSTALL=false
    local UPGRADE=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --system-install-only)
                SYSTEM_INSTALL_ONLY=true
                ;;
            --fresh-install)
                FRESH_INSTALL=true
                ;;
            --upgrade)
                UPGRADE=true
                ;;
            --uninstall)
                uninstall_hnm
                exit 0
                ;;
            --reinstall)
                reinstall_hnm
                exit 0
                ;;
            --help|-h)
                echo "HNM (Huddle Node Manager) Unified Installer"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --help, -h           Show this help message"
                echo "  --uninstall          Uninstall HNM and optionally IPFS"
                echo "  --reinstall          Reinstall HNM with options"
                echo "  --system-install-only  Internal flag for system installation"
                echo ""
                echo "Interactive mode (default):"
                echo "  Run without options for guided installation"
                exit 0
                ;;
        esac
        shift
    done
    
    echo -e "${PURPLE}🏠 Huddle Node Manager (HNM) Unified Installer${NC}"
    echo -e "${CYAN}Modern IPFS node management with enhanced UX${NC}"
    echo -e "${YELLOW}⬆️  Upgraded from original Huddle IPFS Node Manager${NC}"
    echo -e "${GREEN}🔧 Includes comprehensive IPFS node setup${NC}"
    echo ""
    
    # Show management options if HNM is already installed
    if [ "$SYSTEM_INSTALL_ONLY" = "false" ] && [ "$FRESH_INSTALL" = "false" ] && [ "$UPGRADE" = "false" ]; then
        if command -v hnm &> /dev/null || [ -f "$HOME/.local/bin/hnm" ] || [ -f "/usr/local/bin/hnm" ] || [ -f "$HOME/huddle-node-manager/bin/hnm" ]; then
            echo ""
            log_info "🔍 Existing Installation Detected!"
            echo ""
            log_info "Management Options:"
            echo "  1) Continue with new installation/upgrade"
            echo "  2) Uninstall existing installation"
            echo "  3) Reinstall (clean or upgrade)"
            echo "  4) Exit"
            echo ""
            echo -n "Choose option (1-4): "
            read -r mgmt_choice
            
            case "$mgmt_choice" in
                1)
                    log_info "Continuing with installation..."
                    ;;
                2)
                    uninstall_hnm
                    exit 0
                    ;;
                3)
                    reinstall_hnm
                    exit 0
                    ;;
                4)
                    log_info "Exiting installer"
                    exit 0
                    ;;
                *)
                    log_warning "Invalid choice, continuing with installation..."
                    ;;
            esac
        fi
    fi
    
    # Check if we're in the right directory
    if [ ! -f "hnm" ]; then
        log_error "Please run this installer from the huddle-node-manager directory"
        log_info "Required files: hnm"
        exit 1
    fi
    
    # Check and upgrade Python version if needed
    check_and_upgrade_python() {
        log_step "Checking Python version compatibility..."
        
        # Get current Python version
        if command -v python3 &> /dev/null; then
            PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
            PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
            PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
            
            log_info "Current Python version: $PYTHON_VERSION"
            
            # Check if version is 3.10 or higher
            if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
                log_success "Python version is compatible (3.10+)"
                return 0
            else
                log_warning "Python version $PYTHON_VERSION is below recommended 3.10+"
                
                # Try to upgrade Python on macOS
                if [[ "$(uname)" == "Darwin" ]]; then
                    log_step "Attempting to upgrade Python via Homebrew..."
                    
                    # Check if Homebrew is available
                    if command -v brew &> /dev/null; then
                        log_info "Installing Python 3.11 via Homebrew..."
                        brew install python@3.11
                        
                        # Update PATH to use Homebrew Python
                        export PATH="/opt/homebrew/bin:$PATH"
                        
                        # Verify the upgrade
                        if command -v python3 &> /dev/null; then
                            NEW_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
                            NEW_MAJOR=$(echo "$NEW_VERSION" | cut -d. -f1)
                            NEW_MINOR=$(echo "$NEW_VERSION" | cut -d. -f2)
                            
                            if [ "$NEW_MAJOR" -eq 3 ] && [ "$NEW_MINOR" -ge 10 ]; then
                                log_success "Python upgraded to $NEW_VERSION"
                                return 0
                            else
                                log_warning "Python upgrade may not have worked as expected"
                            fi
                        fi
                    else
                        log_warning "Homebrew not available - cannot auto-upgrade Python"
                        log_info "Please install Python 3.10+ manually:"
                        echo "  • macOS: brew install python@3.11"
                        echo "  • Linux: Use your package manager"
                        echo "  • Windows: Download from python.org"
                    fi
                else
                    log_warning "Auto-upgrade not supported on this platform"
                    log_info "Please install Python 3.10+ manually"
                fi
                
                # Ask user if they want to continue anyway
                echo ""
                echo -n "Continue with current Python version? (y/N): "
                read -r continue_anyway
                if [[ "$continue_anyway" =~ ^[Yy]$ ]]; then
                    log_warning "Continuing with Python $PYTHON_VERSION - some packages may not work"
                    return 0
                else
                    log_error "Installation cancelled - please upgrade Python first"
                    exit 1
                fi
            fi
        else
            log_error "Python3 not found"
            log_info "Please install Python 3.10+ first"
            exit 1
        fi
    }
    
    # Detect operating system for installation
    local system=$(detect_os)
    log_info "Detected operating system: $system"
    
    # Check permissions and install accordingly
    if [ "$system" = "Windows" ]; then
        # Use Windows-specific installation
        windows_install
    elif check_permissions; then
        # Running as root - install system-wide
        system_install
    else
        # Ask user preference
        echo ""
        log_info "📋 Installation Options:"
        echo "  1) Install for current user only"
        echo "  2) Install system-wide (requires sudo)"
        echo "  3) Cancel installation"
        echo ""
        
        read -p "Choose option (1-3): " choice
        
        case "$choice" in
            1)
                user_install
                ;;
            2)
                log_info "Running with sudo for system-wide installation..."
                # Re-run this script with sudo
                sudo "$0"
                exit $?
                ;;
            3)
                log_info "Installation cancelled"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    log_success "🎉 HNM installation completed!"
    echo ""
    
    # Automatically setup and start HNM after installation
    log_info "🚀 Automatically setting up and starting HNM..."
    echo ""
    
    # Setup HNM
    log_step "Setting up HNM configuration..."
    if command -v hnm &> /dev/null; then
        if hnm setup; then
            log_success "HNM setup completed successfully"
            
            # Initialize IPFS if not already initialized
            log_step "Checking IPFS initialization..."
            if command -v ipfs &> /dev/null; then
                if [ ! -d "$HOME/.ipfs" ]; then
                    log_step "Initializing IPFS repository..."
                    if ipfs init; then
                        log_success "IPFS repository initialized"
                    else
                        log_warning "Failed to initialize IPFS repository"
                    fi
                else
                    log_success "IPFS repository already exists"
                fi
                
                # Remove stale lock file if it exists
                if [ -f "$HOME/.ipfs/repo.lock" ]; then
                    log_step "Removing stale IPFS lock file..."
                    rm -f "$HOME/.ipfs/repo.lock"
                fi
            fi
            
            # Start HNM
            log_step "Starting HNM services..."
            if hnm start; then
                log_success "HNM started successfully"
                log_info "Your Huddle Node Manager is now running!"
                log_info "Use 'hnm status' to check your node status"
                log_info "Use 'hnm content add [file]' to add content to IPFS"
            else
                log_warning "Failed to start HNM automatically"
                log_info "You can manually start it later with: hnm start"
            fi
        else
            log_warning "Failed to setup HNM automatically"
            log_info "You can manually setup it later with: hnm setup"
        fi
    else
        log_warning "HNM command not found in PATH"
        log_info "Please restart your terminal and run: hnm setup"
    fi
    
    echo ""
    log_info "✨ Backward Compatibility Features:"
    echo "   • All original commands still work:"
    echo "     - ipfs-setup"
    echo "     - ipfs-manager"
    echo "     - ipfs-manager-version"
    echo "     - ipfs-manager-uninstall"
    echo "   • New modern commands available:"
    echo "     - hnm setup"
    echo "     - hnm status"
    echo "     - hnm content add <file>"
    echo "     - hnm community peers"
    echo ""
    log_info "🔧 Content Management Commands:"
    echo "   • Use your familiar commands:"
    echo "     - ipfs-setup                     - Set up your IPFS node"
    echo "     - ipfs-manager                   - Access help and management"
    echo "     - hnm content add [file]         - Add and pin content"
    echo "     - hnm status                     - Check node status"
    echo "     - hnm content pins               - List pinned content"
    echo ""
    log_info "🚀 Advanced Features Installed:"
    echo "   • API Components: Python modules for embeddings, OCR, NLP, and transcription"
    echo "   • ML Models: Pre-trained models for advanced content processing"
    echo "   • Documentation: Comprehensive guides in the doc directory"
    echo "   • Utility Scripts: Additional tools for enhanced functionality"
    echo ""
    log_info "📚 To access advanced API features:"
    echo "   • Python: import apim.client as client"
    echo "   • Shell: hnm keys setup (to configure API keys)"
    echo ""
    log_info "Next steps:"
    echo "  1. Restart your terminal (if needed)"
    echo "  2. Verify installation: python verify_installation.py"
    echo "  3. Setup frontend: python setup_frontend.py"
    echo "  4. Run: hnm setup  (or ipfs-setup) - will be done automatically by complete installer"
    echo "  5. Run: hnm status"
    echo "  6. Test: hnm content add [your-file]"
    echo ""
    log_info "For help: hnm help (or ipfs-manager)"
    log_info "Migration guide: Both old and new commands work side by side!"
    log_info "🐳 Developers: Test across multiple OS with: hnm docker interactive"
    echo ""
    log_success "🌟 Your unified Huddle ecosystem is ready!"
}

# Run main function
main "$@" 