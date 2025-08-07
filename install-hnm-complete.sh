#!/bin/bash

# Complete HNM Installer with Virtual Environment Handling
# This script ensures all Python commands run in the virtual environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}🔄 $1${NC}"
}

echo -e "${BLUE}🚀 Huddle Node Manager - Complete Installation${NC}"
echo "This script ensures all Python commands run in the virtual environment"
echo ""

# Step 1: Run the main installer
log_step "Running main installer..."
./install-hnm.sh

# Step 2: Check for existing or active virtual environment
log_step "Checking for existing virtual environment..."

# Check if we're already in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    log_success "Already in virtual environment: $VIRTUAL_ENV"
    if [ "$VIRTUAL_ENV" = "$(pwd)/hnm_env" ]; then
        log_success "Using existing HNM virtual environment"
    else
        log_warning "Different virtual environment active: $VIRTUAL_ENV"
        log_info "Will use HNM-specific environment"
    fi
fi

# Check for existing hnm_env directory
if [ -d "hnm_env" ]; then
    log_success "HNM virtual environment found"
    
    # Activate virtual environment and run dependency setup
    source hnm_env/bin/activate
    log_success "Virtual environment activated"
    
    # Run dependency setup
    if [ -f "setup_dependencies.py" ]; then
        log_step "Running dependency setup in virtual environment..."
        python3 setup_dependencies.py
        log_success "Dependencies installed successfully"
    else
        log_warning "setup_dependencies.py not found"
    fi
    
    # Verify installation
    log_step "Verifying installation..."
    if [ -f "verify_installation.py" ]; then
        python3 verify_installation.py
    fi
    
    # Run HNM setup to create config files
    log_step "Running HNM setup..."
    if command -v hnm >/dev/null 2>&1; then
        hnm setup
        log_success "HNM setup completed"
    else
        log_warning "HNM command not found in PATH - setup will need to be run manually"
    fi
    
    # Run dynamic installation test
    log_step "Running dynamic installation test..."
    if [ -f "test_installation_paths_dynamic.sh" ]; then
        chmod +x test_installation_paths_dynamic.sh
        
        # Ensure we're in the virtual environment for the test
        if [ -f "activate_huddle_env.sh" ]; then
            log_info "Activating Huddle environment for dynamic test..."
            source activate_huddle_env.sh >/dev/null 2>&1
        elif [ -d "hnm_env" ]; then
            log_info "Activating virtual environment for dynamic test..."
            source hnm_env/bin/activate
        fi
        
        if ./test_installation_paths_dynamic.sh; then
            log_success "✅ Dynamic installation test passed!"
        else
            log_warning "⚠️  Dynamic installation test had issues - check output above"
        fi
    else
        log_warning "test_installation_paths_dynamic.sh not found - skipping dynamic test"
    fi
    
    log_success "🎉 Installation completed successfully!"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Activate your environment: source hnm_env/bin/activate"
    echo "2. Test the installation: python -c 'import torch; print(torch.__version__)'"
    echo "3. Run your GGUF server: python ~/.huddle-node-manager/bundled_models/optimized_gguf_server.py"
    echo "4. Verify HNM setup: hnm status"
    echo "5. Run dynamic test anytime: ./test_installation_paths_dynamic.sh"
    
else
    log_error "Virtual environment not found. Installation may have failed."
    exit 1
fi 