#!/bin/bash

# Linux Compatibility Test for HNM Installation
# Tests the dynamic installation script on various Linux distributions

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

# Function to test a Linux distribution
test_linux_distro() {
    local distro="$1"
    local tag="$2"
    local package_manager="$3"
    
    echo -e "${PURPLE}🧪 Testing $distro ($tag)${NC}"
    echo "=================================="
    
    # Create temporary Dockerfile for testing
    cat > "Dockerfile.test.$distro" << EOF
FROM $tag

# Install basic dependencies based on package manager
RUN case "$package_manager" in \\
    "apt") \\
        apt update -y && \\
        apt install -y curl git python3 python3-pip python3-venv \\
        ;; \\
    "dnf") \\
        dnf update -y && \\
        dnf install -y curl git python3 python3-pip --allowerasing \\
        ;; \\
    "apk") \\
        apk update && \\
        apk add curl git python3 py3-pip bash \\
        ;; \\
    *) \\
        echo "Unknown package manager: $package_manager" && exit 1 \\
        ;; \\
esac

# Create huddle user (platform-specific)
RUN case "$package_manager" in \\
    "apk") \\
        adduser -D -s /bin/bash huddle \\
        ;; \\
    *) \\
        useradd -m -s /bin/bash huddle \\
        ;; \\
esac

# Set working directory
WORKDIR /home/huddle

# Copy test files
COPY test_installation_paths_dynamic.sh ./
COPY device_detection_test.py ./
COPY activate_huddle_env.sh ./
COPY install-hnm-complete.sh ./

# Copy entrypoint script
COPY docker/scripts/entrypoint-linux.sh ./entrypoint.sh
COPY docker/scripts/test-install.sh ./test-install.sh

# Create virtual environment and install dependencies
RUN python3 -m venv hnm_env && \\
    . hnm_env/bin/activate && \\
    pip install --upgrade pip

# Make scripts executable and ensure proper shebang for Alpine
RUN chmod +x *.sh && \\
    case "$package_manager" in \\
        "apk") \\
            sed -i '1s|^#!/bin/bash$|#!/bin/sh|' ./entrypoint.sh \\
            ;; \\
    esac

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
EOF
    
    # Build and run test
    log_step "Building $distro test image..."
    if docker build -f "Dockerfile.test.$distro" -t "hnm-test-$distro" .; then
        log_success "✅ $distro image built successfully"
        
        log_step "Running $distro test..."
        if docker run --rm "hnm-test-$distro"; then
            log_success "✅ $distro test passed!"
            return 0
        else
            log_error "❌ $distro test failed!"
            return 1
        fi
    else
        log_error "❌ Failed to build $distro image"
        return 1
    fi
    
    # Cleanup
    rm -f "Dockerfile.test.$distro"
    docker rmi "hnm-test-$distro" 2>/dev/null || true
}

# Function to test Windows WSL compatibility
test_windows_wsl() {
    echo -e "${PURPLE}🧪 Testing Windows WSL Compatibility${NC}"
    echo "============================================="
    
    # Create WSL-compatible test
    cat > "Dockerfile.test.wsl" << EOF
FROM ubuntu:22.04

# Install WSL-compatible dependencies
RUN apt update -y && \\
    apt install -y curl git python3 python3-pip python3-venv wsl

# Create huddle user (Ubuntu uses useradd)
RUN useradd -m -s /bin/bash huddle

# Set working directory
WORKDIR /home/huddle

# Copy test files
COPY test_installation_paths_dynamic.sh ./
COPY device_detection_test.py ./
COPY activate_huddle_env.sh ./
COPY install-hnm-complete.sh ./

# Copy entrypoint script
COPY docker/scripts/entrypoint-wsl.sh ./entrypoint.sh
COPY docker/scripts/test-install.sh ./test-install.sh

# Create virtual environment and install dependencies
RUN python3 -m venv hnm_env && \\
    . hnm_env/bin/activate && \\
    pip install --upgrade pip

# Make scripts executable
RUN chmod +x *.sh

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
EOF
    
    log_step "Building WSL test image..."
    if docker build -f "Dockerfile.test.wsl" -t "hnm-test-wsl" .; then
        log_success "✅ WSL image built successfully"
        
        log_step "Running WSL test..."
        if docker run --rm "hnm-test-wsl"; then
            log_success "✅ WSL test passed!"
            return 0
        else
            log_error "❌ WSL test failed!"
            return 1
        fi
    else
        log_error "❌ Failed to build WSL image"
        return 1
    fi
    
    # Cleanup
    rm -f "Dockerfile.test.wsl"
    docker rmi "hnm-test-wsl" 2>/dev/null || true
}

# Main test function
main() {
    echo -e "${BLUE}🚀 HNM Linux Compatibility Test${NC}"
    echo "====================================="
    echo ""
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found. Please install Docker to run compatibility tests."
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running. Please start Docker."
        exit 1
    fi
    
    log_success "Docker is available and running"
    echo ""
    
    # Test different Linux distributions
    local all_passed=true
    
    # Ubuntu 22.04 (APT)
    if test_linux_distro "ubuntu" "ubuntu:22.04" "apt"; then
        log_success "✅ Ubuntu 22.04 compatibility confirmed"
    else
        log_error "❌ Ubuntu 22.04 compatibility failed"
        all_passed=false
    fi
    echo ""
    
    # Rocky Linux 9 (DNF) - Modern CentOS replacement
    if test_linux_distro "rocky" "rockylinux:9" "dnf"; then
        log_success "✅ Rocky Linux 9 compatibility confirmed"
    else
        log_error "❌ Rocky Linux 9 compatibility failed"
        all_passed=false
    fi
    echo ""
    
    # Alpine Linux (APK)
    if test_linux_distro "alpine" "alpine:latest" "apk"; then
        log_success "✅ Alpine Linux compatibility confirmed"
    else
        log_error "❌ Alpine Linux compatibility failed"
        all_passed=false
    fi
    echo ""
    
    # Windows WSL compatibility
    if test_windows_wsl; then
        log_success "✅ Windows WSL compatibility confirmed"
    else
        log_error "❌ Windows WSL compatibility failed"
        all_passed=false
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}📊 Compatibility Test Summary${NC}"
    echo "================================"
    
    if [ "$all_passed" = true ]; then
        log_success "🎉 All compatibility tests passed!"
        echo ""
        echo -e "${GREEN}✅ Cross-platform compatibility confirmed:${NC}"
        echo "   • Ubuntu 22.04 (APT)"
        echo "   • Rocky Linux 9 (DNF)"
        echo "   • Alpine Linux (APK)"
        echo "   • Windows WSL"
        echo ""
        log_success "✅ HNM installation is ready for production across platforms!"
    else
        log_error "❌ Some compatibility tests failed"
        echo ""
        echo -e "${YELLOW}Recommendations:${NC}"
        echo "1. Review failed test outputs above"
        echo "2. Fix platform-specific issues"
        echo "3. Re-run compatibility tests"
        echo ""
    fi
    
    # Cleanup any remaining images
    docker rmi $(docker images -q "hnm-test-*") 2>/dev/null || true
}

# Run the test
main "$@" 