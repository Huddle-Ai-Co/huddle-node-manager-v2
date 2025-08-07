#!/bin/bash

# Huddle Node Manager - Compatibility Check Script
# This script verifies all dependencies are available before installation

VERSION="1.2.0"
SCRIPT_NAME="Huddle Node Manager Compatibility Check"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display the banner
display_banner() {
cat << "EOF"
 _   _  _   _  ____  ____  _      _____ 
| | | || | | ||  _ \|  _ \| |    | ____|
| |_| || | | || | | | | | | |    |  _|  
|  _  || |_| || |_| | |_| | |___ | |___ 
|_| |_| \___/ |____/|____/|_____||_____|

========================================================
        Compatibility Check v1.2.0
========================================================
EOF
echo ""
}

# Function to print status messages
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Start compatibility check
display_banner
echo "Checking system compatibility for Huddle Node Manager..."
echo ""

# 1. Check Operating System
print_status "INFO" "Checking operating system..."
OS="$(uname -s)"
case "${OS}" in
    Linux*)     
        SYSTEM=Linux
        print_status "OK" "Operating System: Linux (Supported)"
        ((CHECKS_PASSED++))
        ;;
    Darwin*)    
        SYSTEM=Mac
        print_status "OK" "Operating System: macOS (Supported)"
        ((CHECKS_PASSED++))
        ;;
    CYGWIN*|MINGW*) 
        SYSTEM=Windows
        print_status "WARN" "Operating System: Windows (Limited Support)"
        ((WARNINGS++))
        ;;
    *)          
        SYSTEM="UNKNOWN"
        print_status "ERROR" "Operating System: Unknown/Unsupported"
        ((CHECKS_FAILED++))
        ;;
esac

# 2. Check IPFS
print_status "INFO" "Checking IPFS installation..."
if command_exists ipfs; then
    IPFS_VERSION=$(ipfs version 2>/dev/null | head -n1)
    print_status "OK" "IPFS found: $IPFS_VERSION"
    
    # Test IPFS daemon connectivity
    if ipfs swarm peers >/dev/null 2>&1; then
        print_status "OK" "IPFS daemon is running and connected"
    else
        print_status "WARN" "IPFS daemon not running (will start automatically)"
        ((WARNINGS++))
    fi
    ((CHECKS_PASSED++))
else
    print_status "ERROR" "IPFS not found - Required for node manager"
    print_status "INFO" "Install IPFS from: https://ipfs.io/docs/install/"
    ((CHECKS_FAILED++))
fi

# 3. Check Python
print_status "INFO" "Checking Python installation..."
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_status "OK" "Python found: $PYTHON_VERSION"
    
    # Check Python version (need 3.7+)
    PYTHON_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
    
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 7 ]; then
        print_status "OK" "Python version is compatible (3.7+)"
        ((CHECKS_PASSED++))
    else
        print_status "ERROR" "Python version too old (need 3.7+)"
        ((CHECKS_FAILED++))
    fi
elif command_exists python; then
    PYTHON_VERSION=$(python --version 2>&1)
    print_status "WARN" "Only 'python' command found: $PYTHON_VERSION"
    print_status "INFO" "Recommend installing Python 3.7+ as 'python3'"
    ((WARNINGS++))
else
    print_status "ERROR" "Python not found - Required for FAISS and indexing"
    print_status "INFO" "Install Python 3.7+ from: https://python.org"
    ((CHECKS_FAILED++))
fi

# 4. Check pip
print_status "INFO" "Checking pip installation..."
if command_exists pip3; then
    PIP_VERSION=$(pip3 --version 2>&1)
    print_status "OK" "pip3 found: $PIP_VERSION"
    ((CHECKS_PASSED++))
elif command_exists pip; then
    PIP_VERSION=$(pip --version 2>&1)
    print_status "WARN" "Only 'pip' command found: $PIP_VERSION"
    ((WARNINGS++))
else
    print_status "ERROR" "pip not found - Required for Python packages"
    ((CHECKS_FAILED++))
fi

# 5. Check virtual environment support
print_status "INFO" "Checking Python virtual environment support..."
if python3 -c "import venv" 2>/dev/null; then
    print_status "OK" "Python venv module available"
    ((CHECKS_PASSED++))
elif python3 -c "import virtualenv" 2>/dev/null; then
    print_status "OK" "virtualenv package available"
    ((CHECKS_PASSED++))
else
    print_status "WARN" "No virtual environment support detected"
    print_status "INFO" "Will attempt to create venv during installation"
    ((WARNINGS++))
fi

# 6. Check if FAISS environment already exists
print_status "INFO" "Checking existing FAISS environment..."
if [ -d "faiss_env" ]; then
    print_status "OK" "FAISS environment directory exists"
    
    if [ -f "faiss_env/bin/activate" ] || [ -f "faiss_env/Scripts/activate" ]; then
        print_status "OK" "FAISS environment appears to be set up"
        
        # Test FAISS import
        if source faiss_env/bin/activate 2>/dev/null && python -c "import faiss" 2>/dev/null; then
            FAISS_VERSION=$(source faiss_env/bin/activate 2>/dev/null && python -c "import faiss; print(faiss.__version__)" 2>/dev/null)
            print_status "OK" "FAISS is working: v$FAISS_VERSION"
            ((CHECKS_PASSED++))
        else
            print_status "WARN" "FAISS environment exists but FAISS not working"
            ((WARNINGS++))
        fi
    else
        print_status "WARN" "FAISS environment directory exists but incomplete"
        ((WARNINGS++))
    fi
else
    print_status "INFO" "FAISS environment will be created during installation"
fi

# 7. Check network connectivity
print_status "INFO" "Checking network connectivity..."
if ping -c 1 ipfs.io >/dev/null 2>&1; then
    print_status "OK" "Network connectivity to IPFS.io"
    ((CHECKS_PASSED++))
else
    print_status "WARN" "Cannot reach IPFS.io - may affect installation"
    ((WARNINGS++))
fi

# 8. Check disk space
print_status "INFO" "Checking available disk space..."
if command_exists df; then
    AVAILABLE_SPACE=$(df -h . | tail -1 | awk '{print $4}')
    print_status "OK" "Available disk space: $AVAILABLE_SPACE"
    ((CHECKS_PASSED++))
else
    print_status "WARN" "Cannot check disk space"
    ((WARNINGS++))
fi

# 9. Check curl/wget for downloads
print_status "INFO" "Checking download tools..."
if command_exists curl; then
    print_status "OK" "curl available for downloads"
    ((CHECKS_PASSED++))
elif command_exists wget; then
    print_status "OK" "wget available for downloads"
    ((CHECKS_PASSED++))
else
    print_status "ERROR" "Neither curl nor wget found - Required for downloads"
    ((CHECKS_FAILED++))
fi

# 10. Check shell compatibility
print_status "INFO" "Checking shell compatibility..."
if [ -n "$BASH_VERSION" ]; then
    print_status "OK" "Running in Bash: $BASH_VERSION"
    ((CHECKS_PASSED++))
elif [ -n "$ZSH_VERSION" ]; then
    print_status "OK" "Running in Zsh: $ZSH_VERSION"
    ((CHECKS_PASSED++))
else
    print_status "WARN" "Unknown shell - may have compatibility issues"
    ((WARNINGS++))
fi

# Summary
echo ""
echo "========================================================"
echo "                 COMPATIBILITY SUMMARY"
echo "========================================================"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    print_status "OK" "System is compatible with Huddle Node Manager!"
    echo ""
    echo "Checks passed: $CHECKS_PASSED"
    if [ $WARNINGS -gt 0 ]; then
        echo "Warnings: $WARNINGS"
        echo ""
        print_status "INFO" "You can proceed with installation, but review warnings above."
    else
        echo ""
        print_status "INFO" "All systems green! Ready for installation."
    fi
    echo ""
    echo "To install Huddle Node Manager, run:"
    echo "  ./install.sh"
    echo ""
    exit 0
else
    print_status "ERROR" "System has compatibility issues that must be resolved."
    echo ""
    echo "Checks passed: $CHECKS_PASSED"
    echo "Checks failed: $CHECKS_FAILED"
    echo "Warnings: $WARNINGS"
    echo ""
    print_status "INFO" "Please resolve the errors above before installation."
    echo ""
    exit 1
fi 