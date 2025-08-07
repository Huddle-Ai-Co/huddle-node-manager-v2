#!/bin/bash

# HNM Distribution Completeness Checker
# This script checks if all expected files are present in the distribution package

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

echo -e "${PURPLE}🔍 Huddle Node Manager - Distribution Completeness Checker${NC}"
echo "This script checks if all expected files are present in the distribution package"
echo ""

DIST_DIR="huddle-node-manager-distribution"

if [ ! -d "$DIST_DIR" ]; then
    log_error "Distribution directory not found: $DIST_DIR"
    log_info "Please run: ./package-hnm-for-distribution.sh"
    exit 1
fi

log_success "Found distribution directory: $DIST_DIR"

# Define expected files and directories
EXPECTED_FILES=(
    # Critical installation files
    "install-hnm.sh"
    "install-hnm-complete.sh"
    "hnm"
    "run_hnm_script.sh"
    "activate_huddle_env.sh"
    "device_detection_test.py"
    "test_installation_paths_dynamic.sh"
    "requirements.txt"
    "model_config.json"
    
    # IPFS manager scripts
    "api_key_manager.sh"
    "ipfs-daemon-manager.sh"
    "ipfs-content-manager.sh"
    "ipfs-search-manager.sh"
    "ipfs-cluster-manager.sh"
    "ipfs-troubleshoot-manager.sh"
    "open-ipfs-webui.sh"
    
    # Testing scripts
    "test_linux_compatibility.sh"
    "test_windows_compatibility.bat"
    "test_installation_paths.sh"
)

EXPECTED_DIRS=(
    "scripts"
    "testing"
)

EXPECTED_SCRIPTS_FILES=(
    "activate_huddle_env.sh"
    "batch_indexer.sh"
    "device_detection_test.py"
    "ipfs_ocr_indexer.sh"
    "IPFS_UPLOAD.sh"
    "ipfs-helper.sh"
    "model_config.json"
    "openai_gguf_server.py"
    "optimized_gguf_server.py"
    "optimized_resource_server.py"
    "platform_adaptive_config.py"
    "platform_config.json"
    "requirements.txt"
    "resource_monitor.py"
    "setup_bundled_models.py"
    "setup_dependencies.py"
    "setup_frontend.py"
    "setup_macos_dependencies.py"
    "setup_mira_control_panel.sh"
    "setup_models.sh"
    "setup_system_dependencies.py"
    "verify_installation.py"
    "vllm_style_optimizer.py"
)

EXPECTED_TESTING_FILES=(
    "test_installation_paths_dynamic.sh"
    "test_installation_paths.sh"
    "test_linux_compatibility.sh"
    "test_windows_compatibility.bat"
)

EXPECTED_ZIP_FILES=(
    "bundled_models.zip"
    "Data.zip"
    "docker.zip"
)

# Check expected files in root directory
log_step "Checking expected files in root directory..."
all_files_good=true
for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$DIST_DIR/$file" ]; then
        log_success "✓ $file"
    else
        log_error "✗ $file (MISSING)"
        all_files_good=false
    fi
done

# Check expected directories
log_step "Checking expected directories..."
all_dirs_good=true
for dir in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$DIST_DIR/$dir" ]; then
        log_success "✓ $dir/"
    else
        log_error "✗ $dir/ (MISSING)"
        all_dirs_good=false
    fi
done

# Check expected files in scripts directory
log_step "Checking expected files in scripts directory..."
all_scripts_good=true
for file in "${EXPECTED_SCRIPTS_FILES[@]}"; do
    if [ -f "$DIST_DIR/scripts/$file" ]; then
        log_success "✓ scripts/$file"
    else
        log_error "✗ scripts/$file (MISSING)"
        all_scripts_good=false
    fi
done

# Check expected files in testing directory
log_step "Checking expected files in testing directory..."
all_testing_good=true
for file in "${EXPECTED_TESTING_FILES[@]}"; do
    if [ -f "$DIST_DIR/testing/$file" ]; then
        log_success "✓ testing/$file"
    else
        log_error "✗ testing/$file (MISSING)"
        all_testing_good=false
    fi
done

# Check expected zip files
log_step "Checking expected zip files..."
all_zips_good=true
for file in "${EXPECTED_ZIP_FILES[@]}"; do
    if [ -f "$DIST_DIR/$file" ]; then
        log_success "✓ $file"
    else
        log_error "✗ $file (MISSING)"
        all_zips_good=false
    fi
done

# Check package statistics
log_step "Checking package statistics..."
TOTAL_FILES=$(find "$DIST_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$DIST_DIR" | cut -f1)

echo ""
echo -e "${BLUE}📊 Package Statistics:${NC}"
echo "Total files: $TOTAL_FILES"
echo "Directory size: $TOTAL_SIZE"

# Check if critical files are executable
log_step "Checking executable permissions..."
EXECUTABLE_FILES=(
    "install-hnm.sh"
    "install-hnm-complete.sh"
    "hnm"
    "run_hnm_script.sh"
    "activate_huddle_env.sh"
)

all_executable_good=true
for file in "${EXECUTABLE_FILES[@]}"; do
    if [ -f "$DIST_DIR/$file" ] && [ -x "$DIST_DIR/$file" ]; then
        log_success "✓ $file (executable)"
    elif [ -f "$DIST_DIR/$file" ]; then
        log_warning "⚠️  $file (not executable)"
        all_executable_good=false
    else
        log_error "✗ $file (missing)"
        all_executable_good=false
    fi
done

# Final summary
echo ""
echo -e "${PURPLE}📋 Completeness Summary:${NC}"
echo "=================================="

if [ "$all_files_good" = true ]; then
    log_success "✅ All expected files present"
else
    log_error "❌ Some expected files missing"
fi

if [ "$all_dirs_good" = true ]; then
    log_success "✅ All expected directories present"
else
    log_error "❌ Some expected directories missing"
fi

if [ "$all_scripts_good" = true ]; then
    log_success "✅ All expected scripts files present"
else
    log_error "❌ Some expected scripts files missing"
fi

if [ "$all_testing_good" = true ]; then
    log_success "✅ All expected testing files present"
else
    log_error "❌ Some expected testing files missing"
fi

if [ "$all_zips_good" = true ]; then
    log_success "✅ All expected zip files present"
else
    log_error "❌ Some expected zip files missing"
fi

if [ "$all_executable_good" = true ]; then
    log_success "✅ All critical files are executable"
else
    log_error "❌ Some critical files are not executable"
fi

if [ "$TOTAL_FILES" -gt 50 ]; then
    log_success "✅ Package has sufficient files ($TOTAL_FILES)"
else
    log_warning "⚠️  Package may be incomplete ($TOTAL_FILES files)"
fi

echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "1. If files are missing, run: ./package-hnm-for-distribution.sh"
echo "2. Test installation: cd $DIST_DIR && ./install-hnm-complete.sh"
echo "3. Test Docker: cd $DIST_DIR && unzip docker.zip && hnm docker build"
echo ""

log_success "Completeness check complete!" 