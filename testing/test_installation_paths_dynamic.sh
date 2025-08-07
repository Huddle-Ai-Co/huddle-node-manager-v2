#!/bin/bash

# HNM Installation Path Test Script - Dynamic Cross-Platform Version
# This script dynamically detects the user's device and tests the installation workflow
# across different operating systems and filesystem hierarchies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Function to detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macOS";;
        Linux*)     echo "Linux";;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "Windows";;
        *)          echo "Unknown";;
    esac
}

# Function to detect if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Function to determine installation type and paths
determine_installation_paths() {
    local os=$(detect_os)
    local is_root_user=$(is_root && echo "true" || echo "false")
    
    log_info "Detected OS: $os"
    log_info "Running as root: $is_root_user"
    
    # Define paths based on OS and user type
    if [ "$is_root_user" = "true" ]; then
        # System-wide installation
        HNM_LIB_DIR="/usr/local/lib/huddle-node-manager"
        HNM_DOC_DIR="/usr/local/share/doc/huddle-node-manager"
        HNM_CONFIG_DIR="/etc/huddle-node-manager"
        HNM_BIN_DIR="/usr/local/bin"
        INSTALL_TYPE="system"
    else
        # User-level installation
        case "$os" in
            "macOS"|"Linux")
                HNM_LIB_DIR="$HOME/.local/lib/huddle-node-manager"
                HNM_DOC_DIR="$HOME/.local/share/doc/huddle-node-manager"
                HNM_CONFIG_DIR="$HOME/.config/huddle-node-manager"
                HNM_BIN_DIR="$HOME/.local/bin"
                ;;
            "Windows")
                # Windows paths (if using WSL or similar)
                HNM_LIB_DIR="$HOME/.local/lib/huddle-node-manager"
                HNM_DOC_DIR="$HOME/.local/share/doc/huddle-node-manager"
                HNM_CONFIG_DIR="$HOME/.config/huddle-node-manager"
                HNM_BIN_DIR="$HOME/.local/bin"
                ;;
            *)
                log_error "Unsupported operating system: $os"
                exit 1
                ;;
        esac
        INSTALL_TYPE="user"
    fi
    
    # Runtime directories (same across all platforms)
    HNM_HOME="$HOME/.hnm"
    HNM_PRODUCTION_ROOT="$HOME/.huddle-node-manager"
    
    log_info "Installation Type: $INSTALL_TYPE"
    log_info "Library Directory: $HNM_LIB_DIR"
    log_info "Documentation Directory: $HNM_DOC_DIR"
    log_info "Config Directory: $HNM_CONFIG_DIR"
    log_info "Binary Directory: $HNM_BIN_DIR"
    log_info "Runtime Directory: $HNM_HOME"
    log_info "Production Root: $HNM_PRODUCTION_ROOT"
}

# Function to run device detection
run_device_detection() {
    log_step "Running device detection..."
    
    if [ -f "device_detection_test.py" ]; then
        log_info "Found device_detection_test.py - running device detection..."
        
        # Use the existing activation script
        if [ -f "activate_huddle_env.sh" ]; then
            log_info "Activating Huddle environment using activate_huddle_env.sh..."
            source activate_huddle_env.sh >/dev/null 2>&1
            log_success "Huddle environment activated"
        elif [ -d "hnm_env" ]; then
            log_info "Activating hnm_env virtual environment..."
            source hnm_env/bin/activate
            log_success "Virtual environment activated"
        else
            log_warning "No virtual environment found - device detection may fail due to missing dependencies"
        fi
        
        # Try to run device detection
        if python3 device_detection_test.py 2>/dev/null; then
            log_success "Device detection completed"
            return 0
        else
            log_warning "Device detection failed (missing dependencies), continuing with basic detection"
            return 0  # Don't fail the test, just continue
        fi
    else
        log_warning "device_detection_test.py not found, using basic detection"
        return 0  # Don't fail the test, just continue
    fi
}

# Function to create placeholder file
create_placeholder() {
    local file_path="$1"
    local content="$2"
    local dir_path=$(dirname "$file_path")
    
    # Create directory if it doesn't exist
    mkdir -p "$dir_path"
    
    # Create placeholder file
    echo "$content" > "$file_path"
    log_success "Created: $file_path"
}

# Function to check if directory exists
check_directory() {
    local dir_path="$1"
    local description="$2"
    
    if [ -d "$dir_path" ]; then
        log_success "✅ $description: $dir_path"
        return 0
    else
        log_error "❌ $description: $dir_path (MISSING)"
        return 1
    fi
}

# Function to check if file exists
check_file() {
    local file_path="$1"
    local description="$2"
    
    if [ -f "$file_path" ]; then
        log_success "✅ $description: $file_path"
        return 0
    else
        log_error "❌ $description: $file_path (MISSING)"
        return 1
    fi
}

# Function to check platform-specific requirements
check_platform_requirements() {
    local os=$(detect_os)
    
    log_step "Checking platform-specific requirements for $os..."
    
    case "$os" in
        "macOS")
            # Check for Homebrew
            if command -v brew >/dev/null 2>&1; then
                log_success "✅ Homebrew available"
            else
                log_warning "⚠️  Homebrew not found (may be needed for dependencies)"
            fi
            
            # Check for Xcode Command Line Tools
            if xcode-select -p >/dev/null 2>&1; then
                log_success "✅ Xcode Command Line Tools available"
            else
                log_warning "⚠️  Xcode Command Line Tools not found"
            fi
            ;;
        "Linux")
            # Check for common package managers
            if command -v apt >/dev/null 2>&1; then
                log_success "✅ APT package manager available"
            elif command -v yum >/dev/null 2>&1; then
                log_success "✅ YUM package manager available"
            elif command -v pacman >/dev/null 2>&1; then
                log_success "✅ Pacman package manager available"
            else
                log_warning "⚠️  No common package manager found"
            fi
            ;;
        "Windows")
            # Check for WSL or similar
            if command -v wsl >/dev/null 2>&1; then
                log_success "✅ WSL available"
            else
                log_warning "⚠️  WSL not found (recommended for Windows)"
            fi
            ;;
    esac
}

# Function to test installation paths
test_installation_paths() {
    echo -e "${PURPLE}🧪 HNM Installation Path Test - Dynamic Cross-Platform${NC}"
    echo "================================================================"
    echo ""
    
    # Step 1: Determine paths based on OS and user type
    determine_installation_paths
    echo ""
    
    # Step 2: Run device detection
    run_device_detection
    echo ""
    
    # Step 3: Check platform requirements
    check_platform_requirements
    echo ""
    
    # Step 4: Test existing directory structure
    log_step "Testing existing directory structure..."
    echo ""
    
    local all_good=true
    
    # Check main directories
    check_directory "$HNM_LIB_DIR" "HNM Library Directory" || all_good=false
    check_directory "$HNM_DOC_DIR" "HNM Documentation Directory" || all_good=false
    check_directory "$HNM_CONFIG_DIR" "HNM Config Directory" || all_good=false
    check_directory "$HNM_BIN_DIR" "HNM Binary Directory" || all_good=false
    
    # Check subdirectories
    check_directory "$HNM_LIB_DIR/scripts" "HNM Scripts Directory" || all_good=false
    
    # Check for HNM command
    check_file "$HNM_BIN_DIR/hnm" "HNM Command" || all_good=false
    
    # Check for key files
    check_file "$HNM_LIB_DIR/api_key_manager.sh" "API Key Manager" || all_good=false
    check_file "$HNM_LIB_DIR/ipfs-daemon-manager.sh" "IPFS Daemon Manager" || all_good=false
    check_file "$HNM_LIB_DIR/run_hnm_script.sh" "HNM Script Runner" || all_good=false
    
    # Check if HNM setup was run (config file should exist)
    check_file "$HNM_HOME/config.json" "HNM Configuration" || all_good=false
    
    echo ""
    
    # Step 5: Test write permissions with placeholder files
    log_step "Testing write permissions with placeholder files..."
    echo ""
    
    # Create test files
    create_placeholder "$HNM_LIB_DIR/test_placeholder.txt" "This is a test file created by dynamic installation test script"
    create_placeholder "$HNM_CONFIG_DIR/test_config.json" '{"test": "configuration", "os": "'$(detect_os)'", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    create_placeholder "$HNM_DOC_DIR/test_doc.md" "# Test Documentation\n\nThis is a test documentation file for $(detect_os)."
    
    echo ""
    
    # Step 6: Check HNM runtime directories
    log_step "Testing HNM runtime directories..."
    echo ""
    
    check_directory "$HNM_HOME" "HNM Runtime Directory" || all_good=false
    check_directory "$HNM_HOME/logs" "HNM Logs Directory" || all_good=false
    
    # Check if hnm setup was run (creates config.json)
    if [ -f "$HNM_HOME/config.json" ]; then
        log_success "✅ HNM setup was run (config.json exists)"
    else
        log_warning "⚠️  HNM setup not run - config.json missing"
        log_info "Run: hnm setup to create configuration"
    fi
    
    # Create runtime test file
    create_placeholder "$HNM_HOME/test_runtime.json" '{"runtime_test": true, "os": "'$(detect_os)'", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    
    echo ""
    
    # Step 7: Check production model directory
    log_step "Testing production model directory..."
    echo ""
    
    check_directory "$HNM_PRODUCTION_ROOT" "Production Root Directory" || all_good=false
    check_directory "$HNM_PRODUCTION_ROOT/bundled_models" "Bundled Models Directory" || all_good=false
    
    # Create model test file
    create_placeholder "$HNM_PRODUCTION_ROOT/test_model.txt" "This is a test model file for $(detect_os)"
    
    echo ""
    
    # Step 8: Verify HNM command functionality
    log_step "Testing HNM command functionality..."
    echo ""
    
    if command -v hnm >/dev/null 2>&1; then
        log_success "✅ HNM command is available in PATH"
        hnm --version >/dev/null 2>&1 && log_success "✅ HNM command works" || log_error "❌ HNM command failed"
    else
        log_error "❌ HNM command not found in PATH"
        all_good=false
    fi
    
    echo ""
    
    # Step 9: Check for conflicts
    log_step "Checking for potential conflicts..."
    echo ""
    
    # Check for multiple HNM installations
    local hnm_locations=$(which -a hnm 2>/dev/null | wc -l)
    if [ "$hnm_locations" -gt 1 ]; then
        log_warning "⚠️  Multiple HNM installations found:"
        which -a hnm
    else
        log_success "✅ Single HNM installation found"
    fi
    
    # Check for conflicting directories
    if [ -d "/usr/local/lib/huddle-node-manager" ] && [ "$INSTALL_TYPE" = "user" ]; then
        log_warning "⚠️  System-wide installation found alongside user installation"
    fi
    
    echo ""
    
    # Step 10: Summary
    log_step "Installation Test Summary"
    echo "============================"
    echo ""
    
    if [ "$all_good" = true ]; then
        log_success "🎉 All installation paths are working correctly!"
        echo ""
        echo -e "${BLUE}Operating System:${NC} $(detect_os)"
        echo -e "${BLUE}Installation Type:${NC} $INSTALL_TYPE"
        echo -e "${BLUE}HNM Library:${NC} $HNM_LIB_DIR"
        echo -e "${BLUE}HNM Documentation:${NC} $HNM_DOC_DIR"
        echo -e "${BLUE}HNM Config:${NC} $HNM_CONFIG_DIR"
        echo -e "${BLUE}HNM Binary:${NC} $HNM_BIN_DIR"
        echo -e "${BLUE}HNM Runtime:${NC} $HNM_HOME"
        echo -e "${BLUE}Production Models:${NC} $HNM_PRODUCTION_ROOT"
        echo ""
        log_success "✅ Installation workflow matches template for $(detect_os)!"
    else
        log_error "❌ Some installation paths have issues"
        echo ""
        echo -e "${YELLOW}Recommendations:${NC}"
        echo "1. Run: ./install-hnm-complete.sh"
        echo "2. Run: hnm setup"
        echo "3. Check permissions and paths for $(detect_os)"
        echo ""
    fi
    
    # Cleanup test files
    log_step "Cleaning up test files..."
    rm -f "$HNM_LIB_DIR/test_placeholder.txt"
    rm -f "$HNM_CONFIG_DIR/test_config.json"
    rm -f "$HNM_DOC_DIR/test_doc.md"
    rm -f "$HNM_HOME/test_runtime.json"
    rm -f "$HNM_PRODUCTION_ROOT/test_model.txt"
    log_success "Test files cleaned up"
    
    echo ""
    log_success "Dynamic test completed for $(detect_os)!"
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# Run the dynamic test
test_installation_paths 