#!/bin/bash

# Huddle Node Manager - Robust Cleanup Script
# This script completely cleans up the HNM installation for a fresh start

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}🔄 $1${NC}"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}🧹 Huddle Node Manager - Robust Cleanup${NC}"
echo "This script will completely clean up the HNM installation for a fresh start."
echo ""

# Step 1: Shutdown IPFS daemon
log_step "Shutting down IPFS daemon..."
if command -v ipfs &> /dev/null; then
    if ipfs shutdown 2>/dev/null; then
        log_success "IPFS daemon stopped"
    else
        log_warning "IPFS daemon was not running or already stopped"
    fi
else
    log_warning "IPFS not found in PATH"
fi

# Step 2: Remove virtual environment
log_step "Removing virtual environment..."
if [ -d "hnm_env" ]; then
    rm -rf hnm_env
    log_success "Virtual environment 'hnm_env' removed"
else
    log_info "Virtual environment 'hnm_env' not found"
fi

# Step 3: Remove any other potential virtual environments
log_step "Checking for other virtual environments..."
for env_dir in huddle_env venv env .venv; do
    if [ -d "$env_dir" ]; then
        rm -rf "$env_dir"
        log_success "Removed virtual environment: $env_dir"
    fi
done

# Step 4: Clean up system-level Python packages (if possible)
log_step "Attempting to clean up system Python packages..."
PYTHON_PACKAGES=(
    "torch" "torchvision" "torchaudio" "transformers" "tokenizers"
    "accelerate" "bitsandbytes" "safetensors" "huggingface-hub"
    "fastapi" "uvicorn" "pydantic" "aiohttp"
    "azure-search-documents" "azure-core" "openai"
    "PyPDF2" "python-docx" "beautifulsoup4" "lxml" "nltk"
    "requests" "ipfshttpclient" "tqdm" "python-dotenv"
    "typing-extensions" "ffmpeg-python" "psutil" "cryptography"
    "pint" "pytest" "matplotlib" "jupyter"
    "neurokit2" "PyWavelets" "hrv-analysis" "speechbrain"
    "pydub" "pyttsx3" "pillow" "scikit-image" "pytesseract"
    "pandas" "scikit-learn" "numpy" "scipy" "opencv-python"
    "ultralytics" "easyocr" "librosa" "soundfile" "openai-whisper"
    "einops" "flash-attn" "timm" "sentence-transformers"
)

# Try to uninstall packages with --break-system-packages flag
for package in "${PYTHON_PACKAGES[@]}"; do
    if python3 -m pip show "$package" &>/dev/null; then
        if python3 -m pip uninstall -y "$package" --break-system-packages &>/dev/null; then
            log_success "Removed Python package: $package"
        else
            log_warning "Failed to remove Python package: $package"
        fi
    fi
done

# Step 5: Clean up Homebrew packages (if they exist)
log_step "Cleaning up Homebrew packages..."
HOMEBREW_PACKAGES=("numpy" "scipy" "opencv" "pytorch" "ipfs")

for package in "${HOMEBREW_PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        if brew uninstall --ignore-dependencies "$package" &>/dev/null; then
            log_success "Removed Homebrew package: $package"
        else
            log_warning "Failed to remove Homebrew package: $package"
        fi
    fi
done

# Step 5.5: Clean up IPFS configuration and data
log_step "Cleaning up IPFS configuration and data..."
if [ -d "$HOME/.ipfs" ]; then
    rm -rf "$HOME/.ipfs"
    log_success "Removed IPFS configuration directory: ~/.ipfs"
else
    log_info "IPFS configuration directory not found"
fi

# Remove IPFS LaunchAgent if it exists
if [ -f "$HOME/Library/LaunchAgents/io.ipfs.ipfs.plist" ]; then
    launchctl unload "$HOME/Library/LaunchAgents/io.ipfs.ipfs.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/io.ipfs.ipfs.plist"
    log_success "Removed IPFS LaunchAgent"
fi

# Clean up IPFS cache files
log_step "Cleaning up IPFS cache files..."
IPFS_CACHE_DIRS=(
    "$HOME/Library/Caches/Homebrew/ipfs_bottle_manifest--0.36.0"
    "$HOME/Library/Caches/Homebrew/ipfs--0.36.0"
)

for cache_dir in "${IPFS_CACHE_DIRS[@]}"; do
    if [ -d "$cache_dir" ] || [ -f "$cache_dir" ]; then
        rm -rf "$cache_dir"
        log_success "Removed IPFS cache: $(basename "$cache_dir")"
    fi
done

# Clean up any IPFS download files
find "$HOME/Library/Caches/Homebrew/downloads" -name "*ipfs*" -delete 2>/dev/null && log_success "Removed IPFS download cache files" || log_info "No IPFS download cache files found"

# Clean up Python and NumPy cache files
log_step "Cleaning up Python and NumPy cache files..."
PYTHON_CACHE_DIRS=(
    "$HOME/Library/Caches/Homebrew/python@3.11_bottle_manifest--3.11.13"
    "$HOME/Library/Caches/Homebrew/python@3.11--3.11.13"
    "$HOME/Library/Caches/Homebrew/python@3.12--3.12.11"
    "$HOME/Library/Caches/Homebrew/python@3.13--3.13.5"
    "$HOME/Library/Caches/Homebrew/python@3.13_bottle_manifest--3.13.5-1"
    "$HOME/Library/Caches/Homebrew/python@3.12_bottle_manifest--3.12.11"
    "$HOME/Library/Caches/Homebrew/numpy_bottle_manifest--2.3.2"
    "$HOME/Library/Caches/Homebrew/numpy--2.3.2"
    "$HOME/Library/Caches/com.apple.python"
)

for cache_dir in "${PYTHON_CACHE_DIRS[@]}"; do
    if [ -d "$cache_dir" ] || [ -f "$cache_dir" ]; then
        rm -rf "$cache_dir"
        log_success "Removed Python cache: $(basename "$cache_dir")"
    fi
done

# Clean up any Python/NumPy download files
find "$HOME/Library/Caches/Homebrew/downloads" -name "*python*" -delete 2>/dev/null && log_success "Removed Python download cache files" || log_info "No Python download cache files found"
find "$HOME/Library/Caches/Homebrew/downloads" -name "*numpy*" -delete 2>/dev/null && log_success "Removed NumPy download cache files" || log_info "No NumPy download cache files found"

# Step 6: Clean up configuration files
log_step "Cleaning up configuration files..."
CONFIG_FILES=(
    "device_config.json"
    "macos_environment_setup.sh"
    "platform_config.json"
    ".env"
    "pip.conf"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        log_success "Removed config file: $file"
    fi
done

# Step 7: Clean up any temporary or build files
log_step "Cleaning up temporary and build files..."
TEMP_DIRS=(
    "build"
    "dist"
    "*.egg-info"
    "__pycache__"
    ".pytest_cache"
    ".coverage"
    "htmlcov"
)

for pattern in "${TEMP_DIRS[@]}"; do
    if [ -d "$pattern" ] || [ -f "$pattern" ]; then
        rm -rf $pattern
        log_success "Removed temp files: $pattern"
    fi
done

# Step 8: Clean up any Python cache
log_step "Cleaning up Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name "*.pyo" -delete 2>/dev/null || true

# Step 9: Reset any environment variables
log_step "Resetting environment variables..."
unset PYTHONPATH 2>/dev/null || true
unset VIRTUAL_ENV 2>/dev/null || true

# Step 10: Verify cleanup
log_step "Verifying cleanup..."
echo ""
echo "Cleanup verification:"
echo "====================="

# Check if virtual environment is gone
if [ ! -d "hnm_env" ]; then
    log_success "Virtual environment removed"
else
    log_error "Virtual environment still exists"
fi

# Check if key packages are gone
if ! python3 -c "import torch" 2>/dev/null; then
    log_success "PyTorch removed from system Python"
else
    log_warning "PyTorch still available in system Python"
fi

# Check NumPy - it might be built-in or part of the Python installation
if ! python3 -c "import numpy" 2>/dev/null; then
    log_success "NumPy removed from system Python"
else
    # Check if it's actually a real NumPy installation
    if python3 -c "import numpy; print(numpy.__file__)" 2>/dev/null | grep -q "site-packages"; then
        log_warning "NumPy still available in system Python (user-installed)"
    else
        log_info "NumPy available (likely built-in or system package - this is normal)"
    fi
fi

# Check if config files are gone
if [ ! -f "device_config.json" ] && [ ! -f "platform_config.json" ]; then
    log_success "Configuration files removed"
else
    log_warning "Some configuration files may still exist"
fi

# Check if IPFS is gone
if ! command -v ipfs &>/dev/null; then
    log_success "IPFS removed from system"
else
    log_warning "IPFS still available in system"
fi

if [ ! -d "$HOME/.ipfs" ]; then
    log_success "IPFS configuration removed"
else
    log_warning "IPFS configuration directory still exists"
fi

echo ""
log_success "🎉 Cleanup completed!"

# Check if still in virtual environment and deactivate
echo ""
log_step "Checking if still in virtual environment..."
if [ -n "$VIRTUAL_ENV" ]; then
    echo -e "${YELLOW}⚠️  Still in virtual environment: $VIRTUAL_ENV${NC}"
    echo -e "${BLUE}🔄 Deactivating virtual environment...${NC}"
    deactivate
    echo -e "${GREEN}✅ Virtual environment deactivated${NC}"
else
    echo -e "${GREEN}✅ Not in virtual environment${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run the installer: ./install-hnm.sh"
echo "2. The installer will create a fresh virtual environment"
echo "3. All dependencies will be installed cleanly"
echo ""
echo -e "${YELLOW}Note:${NC} Some system packages may still be available via Homebrew."
echo "This is normal and won't interfere with the virtual environment installation." 