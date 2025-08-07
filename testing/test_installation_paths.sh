#!/bin/bash

# HNM Installation Path Test Script
# This script tests the installation workflow and places placeholder files
# to verify if user vs system level installation works correctly

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

# Main test function
test_installation_paths() {
    echo -e "${PURPLE}🧪 HNM Installation Path Test${NC}"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root - testing SYSTEM-WIDE installation"
        INSTALL_TYPE="system"
    else
        log_info "Running as user - testing USER-LEVEL installation"
        INSTALL_TYPE="user"
    fi
    
    echo ""
    
    # Define expected paths based on installation type
    if [ "$INSTALL_TYPE" = "system" ]; then
        HNM_LIB_DIR="/usr/local/lib/huddle-node-manager"
        HNM_DOC_DIR="/usr/local/share/doc/huddle-node-manager"
        HNM_CONFIG_DIR="/etc/huddle-node-manager"
        HNM_BIN_DIR="/usr/local/bin"
    else
        HNM_LIB_DIR="$HOME/.local/lib/huddle-node-manager"
        HNM_DOC_DIR="$HOME/.local/share/doc/huddle-node-manager"
        HNM_CONFIG_DIR="$HOME/.config/huddle-node-manager"
        HNM_BIN_DIR="$HOME/.local/bin"
    fi
    
    # Test 1: Check existing directories
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
    check_file "$HOME/.hnm/config.json" "HNM Configuration" || all_good=false
    
    echo ""
    
    # Test 2: Create placeholder files to verify write permissions
    log_step "Testing write permissions with placeholder files..."
    echo ""
    
    # Create test files
    create_placeholder "$HNM_LIB_DIR/test_placeholder.txt" "This is a test file created by installation test script"
    create_placeholder "$HNM_CONFIG_DIR/test_config.json" '{"test": "configuration", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    create_placeholder "$HNM_DOC_DIR/test_doc.md" "# Test Documentation\n\nThis is a test documentation file."
    
    echo ""
    
    # Test 3: Check HNM runtime directories
    log_step "Testing HNM runtime directories..."
    echo ""
    
    check_directory "$HOME/.hnm" "HNM Runtime Directory" || all_good=false
    check_directory "$HOME/.hnm/logs" "HNM Logs Directory" || all_good=false
    
    # Check if hnm setup was run (creates config.json)
    if [ -f "$HOME/.hnm/config.json" ]; then
        log_success "✅ HNM setup was run (config.json exists)"
    else
        log_warning "⚠️  HNM setup not run - config.json missing"
        log_info "Run: hnm setup to create configuration"
    fi
    
    # Create runtime test file
    create_placeholder "$HOME/.hnm/test_runtime.json" '{"runtime_test": true, "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    
    echo ""
    
    # Test 4: Check production model directory
    log_step "Testing production model directory..."
    echo ""
    
    check_directory "$HOME/.huddle-node-manager" "Production Root Directory" || all_good=false
    check_directory "$HOME/.huddle-node-manager/bundled_models" "Bundled Models Directory" || all_good=false
    
    # Create model test file
    create_placeholder "$HOME/.huddle-node-manager/test_model.txt" "This is a test model file"
    
    echo ""
    
    # Test 5: Verify HNM command functionality
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
    
    # Test 6: Check for conflicts
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
    
    # Summary
    log_step "Installation Test Summary"
    echo "============================"
    echo ""
    
    if [ "$all_good" = true ]; then
        log_success "🎉 All installation paths are working correctly!"
        echo ""
        echo -e "${BLUE}Installation Type:${NC} $INSTALL_TYPE"
        echo -e "${BLUE}HNM Library:${NC} $HNM_LIB_DIR"
        echo -e "${BLUE}HNM Documentation:${NC} $HNM_DOC_DIR"
        echo -e "${BLUE}HNM Config:${NC} $HNM_CONFIG_DIR"
        echo -e "${BLUE}HNM Binary:${NC} $HNM_BIN_DIR"
        echo -e "${BLUE}HNM Runtime:${NC} $HOME/.hnm"
        echo -e "${BLUE}Production Models:${NC} $HOME/.huddle-node-manager"
        echo ""
        log_success "✅ Installation workflow matches template!"
    else
        log_error "❌ Some installation paths have issues"
        echo ""
        echo -e "${YELLOW}Recommendations:${NC}"
        echo "1. Run: ./install-hnm-complete.sh"
        echo "2. Run: hnm setup"
        echo "3. Check permissions and paths"
        echo ""
    fi
    
    # Cleanup test files
    log_step "Cleaning up test files..."
    rm -f "$HNM_LIB_DIR/test_placeholder.txt"
    rm -f "$HNM_CONFIG_DIR/test_config.json"
    rm -f "$HNM_DOC_DIR/test_doc.md"
    rm -f "$HOME/.hnm/test_runtime.json"
    rm -f "$HOME/.huddle-node-manager/test_model.txt"
    log_success "Test files cleaned up"
    
    echo ""
    log_success "Test completed!"
}

# Run the test
test_installation_paths 