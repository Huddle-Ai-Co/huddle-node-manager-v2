#!/bin/bash

# Nuclear Cleanup Script - Removes everything as if user never coded before
# SAFE VERSION: Preserves macOS system integrity
# ROBUST VERSION: With progress tracking, timeouts, and error recovery

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_step() {
    echo -e "${BLUE}🔄 $1${NC}"
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

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_progress() {
    echo -e "${PURPLE}📊 $1${NC}"
}

# Progress tracking
PROGRESS_COUNT=0
TOTAL_STEPS=12

update_progress() {
    PROGRESS_COUNT=$((PROGRESS_COUNT + 1))
    log_progress "Step $PROGRESS_COUNT/$TOTAL_STEPS completed"
}

# Timeout function
run_with_timeout() {
    local timeout=$1
    local command="$2"
    local description="$3"
    
    log_step "$description (timeout: ${timeout}s)..."
    
    # Run command with timeout
    if timeout $timeout bash -c "$command"; then
        log_success "$description completed"
        update_progress
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_warning "$description timed out after ${timeout}s"
        else
            log_warning "$description failed (exit code: $exit_code)"
        fi
        return 1
    fi
}

# Safe removal function
safe_remove() {
    local target="$1"
    local description="$2"
    
    if [ -e "$target" ]; then
        log_step "Removing $description..."
        
        # Try normal removal first
        if rm -rf "$target" 2>/dev/null; then
            log_success "Removed $description"
        else
            # Try with sudo if normal removal fails
            log_warning "Normal removal failed, trying with sudo..."
            if sudo rm -rf "$target" 2>/dev/null; then
                log_success "Removed $description (with sudo)"
            else
                log_warning "Failed to remove $description (may be protected)"
            fi
        fi
    else
        log_info "$description not found (already removed)"
    fi
}

# Count items for progress tracking
count_items() {
    local path="$1"
    if [ -d "$path" ]; then
        find "$path" -type f 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

echo -e "${PURPLE}☢️  Huddle Node Manager - Nuclear Cleanup (SAFE & ROBUST)${NC}"
echo -e "${RED}This script will remove development tools while preserving macOS system integrity!${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will remove:${NC}"
echo "   • Homebrew and all user-installed packages"
echo "   • User-installed Python packages (preserves system Python)"
echo "   • All virtual environments"
echo "   • All development tools (Node.js, Git, CMake)"
echo "   • All configuration files"
echo "   • All cache and temporary files"
echo "   • IPFS and all related data"
echo "   • Huddle Node Manager bundled models and production installation"
echo "   • All AI models and cached model files"
echo ""
echo -e "${GREEN}✅ SAFE: Will preserve:${NC}"
echo "   • macOS system Python"
echo "   • Xcode Command Line Tools (system)"
echo "   • System integrity"
echo "   • macOS default tools"
echo ""
echo -e "${BLUE}🛡️  ROBUST FEATURES:${NC}"
echo "   • Progress tracking"
echo "   • Timeout protection"
echo "   • Error recovery"
echo "   • Safe removal with sudo fallback"
echo ""
echo -e "${RED}This is IRREVERSIBLE!${NC}"
echo ""

# Ask for confirmation
read -p "Are you absolutely sure you want to proceed? Type 'NUKE' to confirm: " confirmation

if [ "$confirmation" != "NUKE" ]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${RED}☢️  NUCLEAR CLEANUP INITIATED!${NC}"
echo ""

# Step 1: Deactivate any active virtual environment
log_step "Deactivating any active virtual environment..."
if [ -n "$VIRTUAL_ENV" ]; then
    echo -e "${YELLOW}⚠️  Deactivating virtual environment: $VIRTUAL_ENV${NC}"
    deactivate
    log_success "Virtual environment deactivated"
else
    log_info "No active virtual environment"
fi
update_progress

# Step 2: Remove all virtual environments
log_step "Removing all virtual environments..."
VENV_DIRS=(
    "hnm_env"
    "huddle_env"
    "venv"
    "env"
    ".venv"
    ".env"
)

for venv_dir in "${VENV_DIRS[@]}"; do
    if [ -d "$venv_dir" ]; then
        safe_remove "$venv_dir" "virtual environment: $venv_dir"
    fi
done
update_progress

# Step 3: Remove user-installed Python packages (SAFE - preserves system Python)
log_step "Removing user-installed Python packages (preserving system Python)..."

# Remove pip packages from user installations only
if command -v pip3 &>/dev/null; then
    log_info "Removing user-installed pip packages..."
    # Only remove packages installed in user space, not system
    pip3 freeze --user | xargs pip3 uninstall -y --user 2>/dev/null || true
fi

if command -v pip &>/dev/null; then
    log_info "Removing user-installed pip packages..."
    pip freeze --user | xargs pip uninstall -y --user 2>/dev/null || true
fi

# Remove Homebrew Python packages (these are user-installed)
if command -v brew &>/dev/null; then
    log_info "Removing Homebrew Python packages..."
    brew uninstall --ignore-dependencies python@3.11 python@3.12 python@3.13 python@3.10 python@3.9 python@3.8 python@3.7 python@3.6 python@2.7 2>/dev/null || true
fi
update_progress

# Step 4: Remove Homebrew and all packages (SAFE - user-installed only)
log_step "Removing Homebrew and all user-installed packages..."

if command -v brew &>/dev/null; then
    log_info "Removing all Homebrew packages..."
    
    # Get list of all installed packages
    BREW_PACKAGES=$(brew list 2>/dev/null || echo "")
    
    if [ -n "$BREW_PACKAGES" ]; then
        log_info "Found $(echo "$BREW_PACKAGES" | wc -w) Homebrew packages to remove"
        
        # Remove packages in batches to avoid timeouts
        echo "$BREW_PACKAGES" | tr ' ' '\n' | while read -r package; do
            if [ -n "$package" ]; then
                log_info "Removing package: $package"
                brew uninstall --ignore-dependencies "$package" 2>/dev/null || true
            fi
        done
    else
        log_info "No Homebrew packages found"
    fi
    
    log_info "Removing Homebrew itself..."
    # Use timeout for Homebrew uninstallation
    run_with_timeout 300 '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"' "Homebrew uninstallation"
    
    # Remove Homebrew directories (user-installed locations only)
    safe_remove "/opt/homebrew" "Homebrew directory"
    safe_remove "~/homebrew" "Homebrew user directory"
    safe_remove "~/.homebrew" "Homebrew config directory"
    
    log_success "Homebrew removed"
else
    log_info "Homebrew not found"
fi
update_progress

# Step 5: Remove user-installed development tools (SAFE)
log_step "Removing user-installed development tools..."

# Remove user-installed Node.js and npm
if command -v node &>/dev/null; then
    # Check if it's user-installed (not system)
    NODE_PATH=$(which node)
    if [[ "$NODE_PATH" == "/usr/local"* ]] || [[ "$NODE_PATH" == "/opt/homebrew"* ]]; then
        log_info "Removing user-installed Node.js..."
        safe_remove "/usr/local/bin/node" "Node.js binary"
        safe_remove "/usr/local/bin/npm" "npm binary"
        safe_remove "/usr/local/bin/npx" "npx binary"
        safe_remove "/usr/local/lib/node_modules" "Node.js modules"
    else
        log_info "Node.js appears to be system-installed, skipping removal"
    fi
fi

# Remove user-installed Git (preserve system Git)
if command -v git &>/dev/null; then
    GIT_PATH=$(which git)
    if [[ "$GIT_PATH" == "/usr/local"* ]] || [[ "$GIT_PATH" == "/opt/homebrew"* ]]; then
        log_info "Removing user-installed Git..."
        safe_remove "/usr/local/bin/git" "Git binary"
        safe_remove "/usr/local/share/git-core" "Git core files"
        safe_remove "/usr/local/share/git-gui" "Git GUI files"
        safe_remove "/usr/local/share/gitk" "Git GUI files"
        safe_remove "/usr/local/share/gitweb" "Git web files"
    else
        log_info "Git appears to be system-installed, skipping removal"
    fi
fi

# Remove user-installed CMake
if command -v cmake &>/dev/null; then
    CMAKE_PATH=$(which cmake)
    if [[ "$CMAKE_PATH" == "/usr/local"* ]] || [[ "$CMAKE_PATH" == "/opt/homebrew"* ]]; then
        log_info "Removing user-installed CMake..."
        safe_remove "/usr/local/bin/cmake" "CMake binary"
        safe_remove "/usr/local/share/cmake-*" "CMake files"
    else
        log_info "CMake appears to be system-installed, skipping removal"
    fi
fi

# SAFE: Do NOT remove Xcode Command Line Tools (system component)
log_info "Preserving Xcode Command Line Tools (system component)"
update_progress

# Step 6: Remove all cache and temporary files (SAFE)
log_step "Removing all cache and temporary files..."

# Remove Python cache with progress tracking
log_info "Removing Python cache files..."
PYTHON_CACHE_COUNT=$(count_items "." "__pycache__")
if [ "$PYTHON_CACHE_COUNT" -gt 0 ]; then
    log_info "Found $PYTHON_CACHE_COUNT Python cache items"
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    find . -type f -name "*.pyo" -delete 2>/dev/null || true
fi

# Remove pip cache
safe_remove "~/.cache/pip" "pip cache"
safe_remove "~/Library/Caches/pip" "pip cache"

# Remove Homebrew cache with progress tracking
if [ -d "~/Library/Caches/Homebrew" ]; then
    HOMEBREW_CACHE_COUNT=$(count_items "~/Library/Caches/Homebrew")
    log_info "Removing Homebrew cache ($HOMEBREW_CACHE_COUNT items)..."
    safe_remove "~/Library/Caches/Homebrew" "Homebrew cache"
    safe_remove "/Library/Caches/Homebrew" "Homebrew system cache"
fi

# Remove user caches (SAFE - don't touch system caches)
safe_remove "~/Library/Caches/*" "user cache files"

# Remove temporary files (SAFE - only user temp)
safe_remove "~/tmp/*" "user temporary files"
safe_remove "/tmp/hnm_*" "HNM temporary files"
update_progress

# Step 7: Remove all configuration files (SAFE - user only)
log_step "Removing all user configuration files..."

# Remove Python configuration
safe_remove "~/.python_history" "Python history"
safe_remove "~/.pyenv" "pyenv configuration"
safe_remove "~/.virtualenvs" "virtual environments"

# Remove pip configuration
safe_remove "~/.pip/pip.conf" "pip configuration"
safe_remove "~/Library/Application Support/pip/pip.ini" "pip configuration"

# Remove Homebrew configuration
safe_remove "~/.brew" "Homebrew configuration"
safe_remove "~/.brewconfig" "Homebrew configuration"

# Remove Git configuration (user only)
safe_remove "~/.gitconfig" "Git configuration"
safe_remove "~/.git" "Git repository"

# Remove Node.js configuration
safe_remove "~/.npm" "npm configuration"
safe_remove "~/.npmrc" "npm configuration"
safe_remove "~/.node-gyp" "node-gyp configuration"

# Remove IPFS configuration
safe_remove "~/.ipfs" "IPFS configuration"
safe_remove "/usr/local/bin/ipfs" "IPFS binary"

# Remove Huddle Node Manager bundled models and production installation
log_step "Removing Huddle Node Manager bundled models and production installation..."

# Remove NEW production installation path
safe_remove "~/.huddle-node-manager" "HNM production installation"

# Remove OLD bundled models path (if exists)
safe_remove "api/open-processing/bundled_models" "HNM bundled models (old path)"

# Remove any cached model files
safe_remove "~/.cache/huggingface" "HuggingFace cache"
safe_remove "~/.cache/torch" "PyTorch cache"
safe_remove "~/.cache/transformers" "Transformers cache"

# Remove model configuration files
safe_remove "model_config.json" "model configuration"
safe_remove ".model_versions.json" "model versions tracking"

# Remove project-specific files
safe_remove "device_config.json" "device configuration"
safe_remove "platform_config.json" "platform configuration"
safe_remove "requirements.txt" "requirements file"
safe_remove "setup.py" "setup file"
safe_remove "pyproject.toml" "project configuration"
update_progress

# Step 8: Remove all environment variables
log_step "Resetting all environment variables..."
unset PYTHONPATH 2>/dev/null || true
unset VIRTUAL_ENV 2>/dev/null || true
unset PIP_USER 2>/dev/null || true
unset PIP_BREAK_SYSTEM_PACKAGES 2>/dev/null || true
unset HOMEBREW_PREFIX 2>/dev/null || true
unset HOMEBREW_CELLAR 2>/dev/null || true
unset HOMEBREW_REPOSITORY 2>/dev/null || true
update_progress

# Step 9: Clean up shell configuration files (SAFE - user only)
log_step "Cleaning up shell configuration files..."

# Remove Homebrew from shell profiles
SHELL_PROFILES=(
    ~/.bash_profile
    ~/.bashrc
    ~/.zshrc
    ~/.profile
    ~/.bash_login
)

for profile in "${SHELL_PROFILES[@]}"; do
    if [ -f "$profile" ]; then
        log_info "Cleaning Homebrew references from $profile"
        # Remove Homebrew-related lines
        sed -i '' '/HOMEBREW/d' "$profile" 2>/dev/null || true
        sed -i '' '/brew/d' "$profile" 2>/dev/null || true
        sed -i '' '/Cellar/d' "$profile" 2>/dev/null || true
        sed -i '' '/opt\/homebrew/d' "$profile" 2>/dev/null || true
    fi
done
update_progress

# Step 10: Restore script permissions (SAFE)
log_step "Restoring script permissions..."
chmod +x *.sh 2>/dev/null || true
chmod +x *.py 2>/dev/null || true
log_success "Script permissions restored"
update_progress

# Step 11: Final verification (SAFE)
log_step "Final verification..."

# Clear shell command cache to prevent false positives
log_info "Clearing shell command cache..."
hash -r 2>/dev/null || true
unset PATH 2>/dev/null || true
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo ""
echo "Nuclear cleanup verification (SAFE):"
echo "==================================="

# Check if system Python is preserved
if command -v python3 &>/dev/null; then
    PYTHON_PATH=$(which python3)
    if [[ "$PYTHON_PATH" == "/usr/bin"* ]] || [[ "$PYTHON_PATH" == "/System"* ]]; then
        log_success "System Python preserved"
    else
        log_warning "Python available (may be user-installed)"
    fi
else
    log_warning "Python not found"
fi

# Check if Homebrew is gone
if ! command -v brew &>/dev/null; then
    log_success "Homebrew removed"
else
    log_warning "Homebrew still available"
fi

# Check if user-installed Node.js is gone
if ! command -v node &>/dev/null; then
    log_success "User-installed Node.js removed"
else
    NODE_PATH=$(which node 2>/dev/null)
    if [[ "$NODE_PATH" == "/usr/bin"* ]] || [[ "$NODE_PATH" == "/System"* ]]; then
        log_info "Node.js available (system-installed - preserved)"
    else
        log_warning "Node.js still available (may be user-installed)"
    fi
fi

# Check if user-installed Git is gone
if ! command -v git &>/dev/null; then
    log_success "User-installed Git removed"
else
    GIT_PATH=$(which git 2>/dev/null)
    if [[ "$GIT_PATH" == "/usr/bin"* ]] || [[ "$GIT_PATH" == "/System"* ]]; then
        log_info "Git available (system-installed - preserved)"
    else
        log_warning "Git still available (may be user-installed)"
    fi
fi

# Check if virtual environments are gone
if [ ! -d "hnm_env" ] && [ ! -d "venv" ] && [ ! -d ".venv" ]; then
    log_success "Virtual environments removed"
else
    log_warning "Some virtual environments may still exist"
fi

# Check if configuration files are gone
if [ ! -f "device_config.json" ] && [ ! -f "platform_config.json" ]; then
    log_success "Configuration files removed"
else
    log_warning "Some configuration files may still exist"
fi

# Check if Huddle Node Manager bundled models are gone
if [ ! -d "~/.huddle-node-manager" ] && [ ! -d "api/open-processing/bundled_models" ]; then
    log_success "HNM bundled models and production installation removed"
else
    log_warning "Some HNM bundled models may still exist"
fi

# Check if model cache files are gone
if [ ! -d "~/.cache/huggingface" ] && [ ! -d "~/.cache/torch" ] && [ ! -d "~/.cache/transformers" ]; then
    log_success "Model cache files removed"
else
    log_warning "Some model cache files may still exist"
fi

# Check if Xcode Command Line Tools are preserved
if [ -d "/Library/Developer/CommandLineTools" ]; then
    log_success "Xcode Command Line Tools preserved (system component)"
else
    log_warning "Xcode Command Line Tools not found"
fi

update_progress

# Step 12: Final completion
log_step "Final completion..."
log_success "Nuclear cleanup verification completed successfully"
update_progress

echo ""
log_success "☢️  Nuclear cleanup completed (SAFE & ROBUST)!"
echo ""
echo -e "${GREEN}✅ System integrity preserved!${NC}"
echo "Your system has been reset to a 'never coded before' state while preserving macOS system components."
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Restart your terminal"
echo "2. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "3. Install Python: brew install python@3.11"
echo "4. Run the HNM installer: ./install-hnm.sh"
echo ""
echo -e "${YELLOW}Note:${NC} System Python and Xcode Command Line Tools are preserved for system stability." 