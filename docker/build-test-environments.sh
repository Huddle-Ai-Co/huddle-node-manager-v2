#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}HNM Multi-OS Testing Environments${NC}"
echo -e "${BLUE}=================================${NC}"

# Cross-platform timeout function
run_with_timeout() {
    local timeout_duration=$1
    shift
    
    if command -v timeout >/dev/null 2>&1; then
        # Linux/GNU timeout
        timeout "$timeout_duration" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        # macOS with coreutils (brew install coreutils)
        gtimeout "$timeout_duration" "$@"
    else
        # Fallback for macOS without coreutils - use background process
        "$@" &
        local pid=$!
        local count=0
        while [ $count -lt "$timeout_duration" ]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                return $?
            fi
            sleep 1
            ((count++))
        done
        kill "$pid" 2>/dev/null
        return 124  # timeout exit code
    fi
}

# Check Docker prerequisites
check_docker_requirements() {
    echo -e "${YELLOW}🔍 Checking Docker Prerequisites...${NC}"
    
    local docker_available=false
    local docker_running=false
    local buildx_available=false
    local requirements_met=true
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker CLI found${NC}"
        docker_available=true
        
        # Check if Docker daemon is running (with timeout to avoid hanging)
        echo -e "${BLUE}  Checking Docker daemon...${NC}"
        if run_with_timeout 10 docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Docker daemon is running${NC}"
            docker_running=true
            
            # Check Docker version
            local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            echo -e "${BLUE}  Docker version: $docker_version${NC}"
            
            # Check if Docker Buildx is available
            if docker buildx version >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Docker Buildx available${NC}"
                buildx_available=true
            else
                echo -e "${RED}✗ Docker Buildx not available${NC}"
                requirements_met=false
            fi
            
        else
            echo -e "${RED}✗ Docker daemon is not running${NC}"
            docker_running=false
            
            # Offer to start Docker on macOS
            if [[ "$(uname -s)" == "Darwin" ]]; then
                echo -e "${YELLOW}💡 Would you like to start Docker Desktop? (y/N)${NC}"
                read -t 10 -p "Auto-start Docker: " start_docker
                if [[ "$start_docker" =~ ^[Yy]$ ]]; then
                    echo -e "${BLUE}🚀 Starting Docker Desktop...${NC}"
                    open -a Docker
                    echo -e "${YELLOW}⏳ Waiting for Docker to start (up to 60 seconds)...${NC}"
                    
                    # Wait for Docker to start (with progress indicators)
                    local wait_count=0
                    while [ $wait_count -lt 12 ]; do  # 12 * 5 = 60 seconds max
                        if run_with_timeout 5 docker info >/dev/null 2>&1; then
                            echo -e "${GREEN}✅ Docker started successfully!${NC}"
                            docker_running=true
                            
                            # Re-check Buildx
                            if docker buildx version >/dev/null 2>&1; then
                                echo -e "${GREEN}✓ Docker Buildx available${NC}"
                                buildx_available=true
                            fi
                            break
                        fi
                        
                        # Show progress
                        local dots=$(printf "%*s" $((($wait_count % 3) + 1)) "" | tr ' ' '.')
                        echo -ne "\r${BLUE}  Docker starting$dots   ${NC}"
                        sleep 5
                        ((wait_count++))
                    done
                    echo ""  # New line after progress
                    
                    if [ "$docker_running" = false ]; then
                        echo -e "${RED}⚠️  Docker didn't start within 60 seconds${NC}"
                        echo -e "${YELLOW}Please start Docker Desktop manually and try again${NC}"
                    fi
                else
                    echo -e "${YELLOW}⏭️  Skipping Docker auto-start${NC}"
                fi
            fi
            
            if [ "$docker_running" = false ]; then
                requirements_met=false
            fi
        fi
    else
        echo -e "${RED}✗ Docker not found${NC}"
        docker_available=false
        requirements_met=false
    fi
    
    # Check disk space (need at least 4GB)
    local available_space_gb
    case "$(uname -s)" in
        Darwin)
            available_space_gb=$(df -g . | awk 'NR==2 {print $4}')
            ;;
        Linux)
            available_space_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
            ;;
        *)
            available_space_gb=10  # Assume sufficient space on other systems
            ;;
    esac
    
    if [ "$available_space_gb" -ge 4 ]; then
        echo -e "${GREEN}✓ Sufficient disk space (${available_space_gb}GB available)${NC}"
    else
        echo -e "${RED}✗ Insufficient disk space (${available_space_gb}GB available, need 4GB+)${NC}"
        requirements_met=false
    fi
    
    echo ""
    
    if [ "$requirements_met" = true ]; then
        echo -e "${GREEN}🎉 All Docker requirements met!${NC}"
        return 0
    else
        echo -e "${RED}❌ Docker requirements not met${NC}"
        show_docker_installation_guide "$docker_available" "$docker_running" "$buildx_available"
        return 1
    fi
}

# Show OS-specific Docker installation guide
show_docker_installation_guide() {
    local docker_available=$1
    local docker_running=$2
    local buildx_available=$3
    local os_type=$(uname -s)
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Docker Installation Guide${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    case "$os_type" in
        Darwin)
            echo -e "${YELLOW}macOS Docker Installation:${NC}"
            if [ "$docker_available" = false ]; then
                echo -e "${BLUE}Option 1: Docker Desktop (Recommended)${NC}"
                echo -e "  • Download: https://docs.docker.com/desktop/mac/install/"
                echo -e "  • Or run: brew install --cask docker"
                echo ""
                echo -e "${BLUE}Option 2: Homebrew${NC}"
                echo -e "  • Run: brew install docker docker-compose"
                echo -e "  • Note: Requires Docker Desktop or Colima for daemon"
            elif [ "$docker_running" = false ]; then
                echo -e "${BLUE}Start Docker:${NC}"
                echo -e "  • Open Docker Desktop application"
                echo -e "  • Or run: open -a Docker"
                echo -e "  • Wait for Docker to start (may take 1-2 minutes)"
            elif [ "$buildx_available" = false ]; then
                echo -e "${BLUE}Enable Docker Buildx:${NC}"
                echo -e "  • Docker Desktop → Settings → Features in development → Check 'Use Docker Compose V2'"
                echo -e "  • Or update Docker Desktop to latest version"
            fi
            ;;
        Linux)
            echo -e "${YELLOW}Linux Docker Installation:${NC}"
            if [ "$docker_available" = false ]; then
                echo -e "${BLUE}Ubuntu/Debian:${NC}"
                echo -e "  sudo apt update"
                echo -e "  sudo apt install docker.io docker-compose-plugin"
                echo -e "  sudo systemctl start docker"
                echo -e "  sudo usermod -aG docker \$USER"
                echo ""
                echo -e "${BLUE}CentOS/RHEL/Fedora:${NC}"
                echo -e "  sudo dnf install docker docker-compose-plugin"
                echo -e "  sudo systemctl start docker"
                echo -e "  sudo usermod -aG docker \$USER"
                echo ""
                echo -e "${BLUE}Arch Linux:${NC}"
                echo -e "  sudo pacman -S docker docker-compose"
                echo -e "  sudo systemctl start docker"
                echo -e "  sudo usermod -aG docker \$USER"
            elif [ "$docker_running" = false ]; then
                echo -e "${BLUE}Start Docker:${NC}"
                echo -e "  sudo systemctl start docker"
                echo -e "  sudo systemctl enable docker  # Auto-start on boot"
            elif [ "$buildx_available" = false ]; then
                echo -e "${BLUE}Install Docker Buildx:${NC}"
                echo -e "  # Usually included in recent Docker versions"
                echo -e "  # If missing: sudo apt install docker-buildx-plugin"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            echo -e "${YELLOW}Windows Docker Installation:${NC}"
            echo -e "${BLUE}Docker Desktop for Windows:${NC}"
            echo -e "  • Download: https://docs.docker.com/desktop/windows/install/"
            echo -e "  • Requires Windows 10/11 with WSL2"
            echo -e "  • Enable 'Use the WSL 2 based engine' in settings"
            ;;
        *)
            echo -e "${YELLOW}General Docker Installation:${NC}"
            echo -e "  • Visit: https://docs.docker.com/get-docker/"
            echo -e "  • Follow instructions for your operating system"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}After Installation:${NC}"
    echo -e "  1. Restart your terminal/shell"
    echo -e "  2. Run: docker --version"
    echo -e "  3. Run: docker info"
    echo -e "  4. Try again: ./build-test-environments.sh"
    echo ""
    echo -e "${CYAN}💡 Quick Test Commands:${NC}"
    echo -e "  docker run hello-world    # Test basic Docker functionality"
    echo -e "  docker buildx version     # Verify buildx is available"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Auto-install Docker with user permission
offer_docker_installation() {
    local os_type=$(uname -s)
    
    echo ""
    echo -e "${YELLOW}🤔 Would you like to attempt automatic Docker installation?${NC}"
    echo -e "${BLUE}Available for:${NC}"
    case "$os_type" in
        Darwin)
            echo -e "  • Homebrew installation (brew install --cask docker)"
            ;;
        Linux)
            if command -v apt >/dev/null 2>&1; then
                echo -e "  • Ubuntu/Debian (apt install docker.io)"
            elif command -v dnf >/dev/null 2>&1; then
                echo -e "  • Fedora/CentOS (dnf install docker)"
            elif command -v pacman >/dev/null 2>&1; then
                echo -e "  • Arch Linux (pacman -S docker)"
            else
                echo -e "  • Not available for your Linux distribution"
                return 1
            fi
            ;;
        *)
            echo -e "  • Not available for your operating system"
            return 1
            ;;
    esac
    
    echo ""
    read -p "Install Docker automatically? (y/n): " install_choice
    
    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        auto_install_docker
        return $?
    else
        echo -e "${BLUE}Please install Docker manually using the guide above${NC}"
        return 1
    fi
}

# Auto-install Docker based on OS
auto_install_docker() {
    local os_type=$(uname -s)
    
    echo -e "${YELLOW}🔧 Installing Docker...${NC}"
    
    case "$os_type" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                echo -e "${BLUE}Installing Docker Desktop via Homebrew...${NC}"
                brew install --cask docker
                echo -e "${GREEN}✓ Docker Desktop installed${NC}"
                echo -e "${YELLOW}Please start Docker Desktop manually:${NC}"
                echo -e "  open -a Docker"
            else
                echo -e "${RED}Homebrew not found. Please install Docker Desktop manually.${NC}"
                return 1
            fi
            ;;
        Linux)
            if command -v apt >/dev/null 2>&1; then
                echo -e "${BLUE}Installing Docker via apt...${NC}"
                sudo apt update
                sudo apt install -y docker.io docker-compose-plugin
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker "$USER"
                echo -e "${GREEN}✓ Docker installed${NC}"
                echo -e "${YELLOW}Please log out and back in for group changes to take effect${NC}"
            elif command -v dnf >/dev/null 2>&1; then
                echo -e "${BLUE}Installing Docker via dnf...${NC}"
                sudo dnf install -y docker docker-compose-plugin
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker "$USER"
                echo -e "${GREEN}✓ Docker installed${NC}"
                echo -e "${YELLOW}Please log out and back in for group changes to take effect${NC}"
            elif command -v pacman >/dev/null 2>&1; then
                echo -e "${BLUE}Installing Docker via pacman...${NC}"
                sudo pacman -S --noconfirm docker docker-compose
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker "$USER"
                echo -e "${GREEN}✓ Docker installed${NC}"
                echo -e "${YELLOW}Please log out and back in for group changes to take effect${NC}"
            else
                echo -e "${RED}Package manager not supported for auto-installation${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Auto-installation not supported for your operating system${NC}"
            return 1
            ;;
    esac
    
    return 0
}

# Define available operating systems
get_os_image() {
    case "$1" in
        "ubuntu20") echo "ubuntu:20.04" ;;
        "ubuntu22") echo "ubuntu:22.04" ;;
        "ubuntu24") echo "ubuntu:24.04" ;;
        "debian11") echo "debian:11-slim" ;;
        "debian12") echo "debian:12-slim" ;;
        "centos7") echo "centos:7" ;;
        "centos9") echo "quay.io/centos/centos:stream9" ;;
        "rocky8") echo "rockylinux:8" ;;
        "rocky9") echo "rockylinux:9" ;;
        "alpine") echo "alpine:latest" ;;
        "fedora") echo "fedora:latest" ;;
        "opensuse") echo "opensuse/leap:15" ;;
        "archlinux") echo "archlinux:latest" ;;
        "amazonlinux") echo "amazonlinux:latest" ;;
        # Specialized simulation environments
        "macos") echo "ubuntu:22.04" ;;  # Base Ubuntu with macOS simulation
        "mingw") echo "ubuntu:22.04" ;;  # Base Ubuntu with MinGW simulation
        "wsl") echo "ubuntu:22.04" ;;    # Base Ubuntu with WSL simulation
        *) echo "" ;;
    esac
}

# Platform architectures
get_platform() {
    case "$1" in
        "amd64") echo "linux/amd64" ;;
        "arm64") echo "linux/arm64" ;;
        "arm") echo "linux/arm/v7" ;;
        *) echo "" ;;
    esac
}

# Check if OS is valid
is_valid_os() {
    local os_image=$(get_os_image "$1")
    [ -n "$os_image" ]
}

# Check if platform is valid
is_valid_platform() {
    local platform=$(get_platform "$1")
    [ -n "$platform" ]
}

# Detect host architecture
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
    x86_64)
        HOST_ARCH_TYPE="amd64"
        ;;
    aarch64|arm64)
        HOST_ARCH_TYPE="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $HOST_ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}Detected host architecture: $HOST_ARCH ($HOST_ARCH_TYPE)${NC}"

# Check Docker requirements first (unless showing help)
if [[ "$1" != "help" && "$1" != "--help" && "$1" != "-h" && "$1" != "show-os" ]]; then
    if ! check_docker_requirements; then
        echo ""
        if ! offer_docker_installation; then
            echo ""
            echo -e "${RED}❌ Cannot proceed without Docker${NC}"
            echo -e "${BLUE}Please install Docker and try again${NC}"
            exit 1
        fi
        
        # Re-check requirements after installation attempt
        echo ""
        echo -e "${YELLOW}Rechecking Docker requirements...${NC}"
        if ! check_docker_requirements; then
            echo ""
            echo -e "${RED}❌ Docker requirements still not met${NC}"
            echo -e "${BLUE}You may need to restart your terminal or start Docker manually${NC}"
            exit 1
        fi
    fi
    echo ""
fi

# Set up QEMU for cross-platform builds
setup_qemu() {
    echo -e "${BLUE}Setting up QEMU for cross-platform builds...${NC}"
    docker run --privileged --rm tonistiigi/binfmt --install all
    docker buildx create --use --name multi-arch-builder || true
    docker buildx inspect --bootstrap
    echo -e "${GREEN}QEMU setup complete${NC}"
}

# Function to show available operating systems
show_os_menu() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Available Operating Systems${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}Ubuntu Variants:${NC}"
    echo -e "  ${BLUE}ubuntu20${NC}      Ubuntu 20.04 LTS"
    echo -e "  ${BLUE}ubuntu22${NC}      Ubuntu 22.04 LTS (Default)"
    echo -e "  ${BLUE}ubuntu24${NC}      Ubuntu 24.04 LTS"
    
    echo -e "${YELLOW}Debian Variants:${NC}"
    echo -e "  ${BLUE}debian11${NC}      Debian 11 (Bullseye)"
    echo -e "  ${BLUE}debian12${NC}      Debian 12 (Bookworm)"
    
    echo -e "${YELLOW}Enterprise Linux:${NC}"
    echo -e "  ${BLUE}centos7${NC}       CentOS 7"
    echo -e "  ${BLUE}centos9${NC}       CentOS Stream 9"
    echo -e "  ${BLUE}rocky8${NC}        Rocky Linux 8"
    echo -e "  ${BLUE}rocky9${NC}        Rocky Linux 9"
    echo -e "  ${BLUE}amazonlinux${NC}   Amazon Linux Latest"
    
    echo -e "${YELLOW}Other Distributions:${NC}"
    echo -e "  ${BLUE}alpine${NC}        Alpine Linux (Minimal)"
    echo -e "  ${BLUE}fedora${NC}        Fedora Latest"
    echo -e "  ${BLUE}opensuse${NC}      openSUSE Leap 15"
    echo -e "  ${BLUE}archlinux${NC}     Arch Linux"
    
    echo -e "${YELLOW}Specialized Environments:${NC}"
    echo -e "  ${BLUE}macos${NC}         macOS simulation (Homebrew, Darwin)"
    echo -e "  ${BLUE}mingw${NC}         MinGW/Git Bash simulation (Windows)"
    echo -e "  ${BLUE}wsl${NC}           Windows Subsystem for Linux simulation"
    
    echo -e "${YELLOW}Platform Architectures:${NC}"
    echo -e "  ${BLUE}amd64${NC}         x86_64 (Intel/AMD)"
    echo -e "  ${BLUE}arm64${NC}         ARM64 (Apple Silicon, ARM servers)"
    echo -e "  ${BLUE}arm${NC}           ARM v7 (Raspberry Pi, etc.)"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check if Docker image exists
check_image_exists() {
    local image_name=$1
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${image_name}:latest$"
}

# Function to show existing HNM images
show_existing_images() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📦 Existing HNM Docker Images:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "^hnm-" | head -20)
    
    if [ -z "$images" ]; then
        echo -e "${YELLOW}No HNM Docker images found.${NC}"
        echo -e "${BLUE}Run 'hnm docker build' to create images.${NC}"
    else
        echo -e "${GREEN}Image Name\t\t\tTag\tSize\t\tCreated${NC}"
        echo "$images"
        echo ""
        local count=$(echo "$images" | wc -l)
        echo -e "${YELLOW}Total: $count HNM images${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to get image size for display
get_image_info() {
    local image_name=$1
    docker images --format "{{.Size}}\t{{.CreatedSince}}" "$image_name:latest" 2>/dev/null
}

# Function to create dynamic Dockerfile based on OS
create_dynamic_dockerfile() {
    local os=$1
    local base_image=$2
    
    # Map OS to appropriate entrypoint script
    local entrypoint_script=""
    case "$os" in
        ubuntu*|debian*|alpine*|fedora*|opensuse*|archlinux*)
            entrypoint_script="entrypoint-linux.sh"
            ;;
        centos*|rocky*|amazonlinux*)
            # Use Linux entrypoint for RHEL-based systems
            entrypoint_script="entrypoint-linux.sh"
            ;;
        macos*)
            entrypoint_script="entrypoint-macos.sh"
            ;;
        mingw*)
            entrypoint_script="entrypoint-mingw.sh"
            ;;
        wsl*)
            entrypoint_script="entrypoint-wsl.sh"
            ;;
        *)
            entrypoint_script="entrypoint-linux.sh"  # Default fallback
            ;;
    esac
    
    cat > Dockerfile.dynamic << EOF
FROM $base_image

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

EOF

    # Add OS-specific package installation
    case "$os" in
        ubuntu*|debian*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for Debian/Ubuntu
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    python3 \
    python3-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    build-essential \
    cmake \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
EOF
            ;;
        centos*|rocky*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for CentOS/Rocky
RUN if command -v yum >/dev/null 2>&1; then \
        yum update -y && yum install -y \
        curl \
        wget \
        git \
        sudo \
        python3 \
        python3-pip \
        bash \
        jq \
        unzip \
        vim \
        nano \
        gcc \
        gcc-c++ \
        make \
        cmake \
        pkgconfig \
        && yum clean all; \
    else \
        dnf update -y && dnf install -y \
        curl \
        wget \
        git \
        sudo \
        python3 \
        python3-pip \
        bash \
        jq \
        unzip \
        vim \
        nano \
        gcc \
        gcc-c++ \
        make \
        cmake \
        pkgconfig \
        && dnf clean all; \
    fi
EOF
            ;;
        alpine*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for Alpine
RUN apk update && apk add --no-cache \
    curl \
    wget \
    git \
    sudo \
    python3 \
    py3-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    build-base \
    cmake \
    pkgconfig
EOF
            ;;
        fedora*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for Fedora
RUN dnf update -y && dnf install -y \
    curl \
    wget \
    git \
    sudo \
    python3 \
    python3-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    gcc \
    gcc-c++ \
    make \
    cmake \
    pkgconfig \
    && dnf clean all
EOF
            ;;
        opensuse*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for openSUSE
RUN zypper refresh && zypper install -y \
    curl \
    wget \
    git \
    sudo \
    python3 \
    python3-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    gcc \
    gcc-c++ \
    make \
    cmake \
    pkg-config \
    && zypper clean -a
EOF
            ;;
        archlinux*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for Arch Linux
RUN pacman -Sy --noconfirm \
    curl \
    wget \
    git \
    sudo \
    python \
    python-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    base-devel \
    cmake \
    pkgconfig \
    && pacman -Scc --noconfirm
EOF
            ;;
        amazonlinux*)
            cat >> Dockerfile.dynamic << 'EOF'
# Install dependencies for Amazon Linux
RUN yum update -y && yum install -y \
    curl \
    wget \
    git \
    sudo \
    python3 \
    python3-pip \
    bash \
    jq \
    unzip \
    vim \
    nano \
    gcc \
    gcc-c++ \
    make \
    cmake \
    pkgconfig \
    && yum clean all
EOF
            ;;
    esac

    cat >> Dockerfile.dynamic << 'EOF'

# Create a non-root user
RUN if ! getent group huddle >/dev/null; then \
        if command -v groupadd >/dev/null 2>&1; then \
            groupadd huddle; \
        else \
            addgroup huddle; \
        fi; \
    fi && \
    if ! getent passwd huddle >/dev/null; then \
        if command -v useradd >/dev/null 2>&1; then \
            useradd -m -s /bin/bash -g huddle huddle; \
        else \
            adduser -D -s /bin/bash -G huddle huddle; \
        fi; \
    fi

# Configure sudo
RUN if [ -d /etc/sudoers.d ]; then \
        echo "huddle ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/huddle; \
    elif [ -f /etc/sudoers ]; then \
        echo "huddle ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    fi

# Switch to the non-root user
USER huddle
WORKDIR /home/huddle

# Create the huddle-node-manager directory
RUN mkdir -p huddle-node-manager

# Copy the complete HNM distribution package for fresh installation simulation
COPY --chown=huddle:huddle huddle-node-manager-distribution/ /home/huddle/huddle-node-manager-distribution/

EOF

    # Add entrypoint script copying and configuration
    cat >> Dockerfile.dynamic << EOF
# Copy entrypoint and test scripts
COPY --chown=huddle:huddle docker/scripts/$entrypoint_script /home/huddle/entrypoint.sh
COPY --chown=huddle:huddle docker/scripts/test-install.sh /home/huddle/test-install.sh
RUN chmod +x /home/huddle/entrypoint.sh /home/huddle/test-install.sh

# Set the entrypoint
ENTRYPOINT ["/home/huddle/entrypoint.sh"]
EOF
}

# Function to build a specific environment
build_environment() {
    local os=${1:-ubuntu22}
    local platform=${2:-$HOST_ARCH_TYPE}
    local force_rebuild=${3:-false}
    
    if ! is_valid_os "$os"; then
        echo -e "${RED}Invalid OS: $os${NC}"
        show_os_menu
        return 1
    fi
    
    if ! is_valid_platform "$platform"; then
        echo -e "${RED}Invalid platform: $platform${NC}"
        echo -e "${YELLOW}Valid platforms: amd64, arm64, arm${NC}"
        return 1
    fi
    
    local base_image=$(get_os_image "$os")
    local container_name="hnm-${os}-${platform//\//-}"
    
    # Check if image already exists
    if check_image_exists "$container_name" && [ "$force_rebuild" != "true" ]; then
        local image_info=$(get_image_info "$container_name")
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}📦 Image Already Exists: $container_name${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        if [ -n "$image_info" ]; then
            echo -e "${GREEN}Size: $(echo $image_info | cut -f1)  Created: $(echo $image_info | cut -f2)${NC}"
        fi
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo -e "  ${BLUE}1)${NC} Skip building (use existing image)"
        echo -e "  ${BLUE}2)${NC} Rebuild anyway (overwrite existing)"
        echo -e "  ${BLUE}3)${NC} Cancel"
        echo ""
        read -p "Choose option (1-3) [1]: " choice
        choice=${choice:-1}
        
        case $choice in
            1)
                echo -e "${GREEN}✅ Using existing image: $container_name${NC}"
                show_container_usage_info "$container_name" "$os" "$platform"
                return 0
                ;;
            2)
                echo -e "${YELLOW}🔄 Rebuilding image: $container_name${NC}"
                ;;
            3)
                echo -e "${YELLOW}❌ Build cancelled${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Using existing image.${NC}"
                show_container_usage_info "$container_name" "$os" "$platform"
                return 0
                ;;
        esac
    fi
    
    echo -e "${CYAN}Building $os environment for $platform...${NC}"
    echo -e "${YELLOW}Building $os environment for $platform...${NC}"
    echo -e "${BLUE}Base image: $base_image${NC}"
    echo -e "${BLUE}Container name: $container_name${NC}"
    
    # Create a dynamic Dockerfile
    create_dynamic_dockerfile "$os" "$base_image"
    
    # Build the Docker image with platform-specific architecture
    echo -e "${YELLOW}🔨 Building Docker image...${NC}"
    docker buildx build --platform $(get_platform "$platform") -t $container_name -f Dockerfile.dynamic --load .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully built $container_name${NC}"
        show_container_usage_info "$container_name" "$os" "$platform"
        # Clean up dynamic Dockerfile
        rm -f Dockerfile.dynamic
    else
        echo -e "${RED}Failed to build $container_name${NC}"
        rm -f Dockerfile.dynamic
        return 1
    fi
}

# Function to show container usage information
show_container_usage_info() {
    local container_name=$1
    local os=$2
    local platform=$3
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🚀 Container ready! Usage examples:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}📋 Manual testing (interactive):${NC}"
    echo -e "  ${BLUE}docker run --rm -it \\${NC}"
    echo -e "    ${BLUE}-v \$(pwd)/..:/home/huddle/huddle-node-manager:rw \\${NC}"
    echo -e "    ${BLUE}$container_name${NC}"
    echo ""
    echo -e "${GREEN}🧪 Automated testing:${NC}"
    echo -e "  ${BLUE}./build-test-environments.sh test $os $platform${NC}"
    echo ""
    echo -e "${GREEN}🔧 Development mode (persistent container):${NC}"
    echo -e "  ${BLUE}docker run -d --name hnm-dev \\${NC}"
    echo -e "    ${BLUE}-v \$(pwd)/..:/home/huddle/huddle-node-manager:rw \\${NC}"
    echo -e "    ${BLUE}$container_name tail -f /dev/null${NC}"
    echo -e "  ${BLUE}docker exec -it hnm-dev bash${NC}"
    echo ""
    echo -e "${YELLOW}💡 Inside the container, run:${NC}"
    echo -e "  ${BLUE}cd ~/huddle-node-manager && ./install-hnm.sh${NC}"
    echo -e "  ${BLUE}~/test-install.sh${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to build all environments
build_all_environments() {
    local force_rebuild=${1:-false}
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🏗️  Building HNM Core Testing Environments${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check prerequisites first
    check_docker_requirements
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    setup_qemu
    
    # Build core environments
    local core_environments=(
        "ubuntu22:amd64"
        "debian12:amd64"  
        "centos9:amd64"
        "alpine:amd64"
        "macos:amd64"
    )
    
    local success_count=0
    local total_count=${#core_environments[@]}
    
    for env_spec in "${core_environments[@]}"; do
        local os=$(echo "$env_spec" | cut -d':' -f1)
        local arch=$(echo "$env_spec" | cut -d':' -f2)
        
        echo -e "\n${YELLOW}📦 Building $os for $arch ($((success_count + 1))/$total_count)...${NC}"
        
        if build_environment "$os" "$arch" "$force_rebuild"; then
            ((success_count++))
            echo -e "${GREEN}✅ Successfully built: hnm-${os}-${arch}${NC}"
        else
            echo -e "${RED}❌ Failed to build: hnm-${os}-${arch}${NC}"
        fi
    done
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📊 Build Summary: $success_count/$total_count environments built successfully${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ $success_count -gt 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 HNM testing environments are ready!${NC}"
        echo -e "${BLUE}Use './build-test-environments.sh test' to run tests${NC}"
        echo -e "${BLUE}Use './build-test-environments.sh list' to see all images${NC}"
    fi
}

# Function to run tests in a specific environment
run_tests_in_env() {
    local os=$1
    local platform=${2:-$HOST_ARCH_TYPE}
    local container_name="hnm-${os}-${platform//\//-}"
    
    echo -e "${YELLOW}Running tests in $os ($platform) environment...${NC}"
    
    # Remove existing container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        echo -e "${BLUE}Removing existing $container_name container...${NC}"
        docker rm -f $container_name >/dev/null 2>&1
    fi
    
    # Start the container with tty and keep it running
    echo -e "${BLUE}Starting $container_name container...${NC}"
    docker run -d --name $container_name \
        -v $(pwd)/..:/home/huddle/huddle-node-manager \
        --entrypoint "/bin/bash" \
        $container_name \
        -c "tail -f /dev/null"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        echo -e "${RED}Failed to start $container_name container.${NC}"
        return 1
    fi
    
    # Copy the test script to the container
    echo -e "${BLUE}Copying test script to container...${NC}"
    docker cp $(pwd)/scripts/test-install.sh $container_name:/home/huddle/test-install.sh
    docker exec $container_name bash -c "chmod +x /home/huddle/test-install.sh"
    
    # Run the test script
    echo -e "${BLUE}Running test script in container...${NC}"
    docker exec $container_name bash -c "/home/huddle/test-install.sh"
    
    echo -e "${GREEN}Tests completed for $container_name${NC}"
}

# Function to run tests in all environments
run_all_tests() {
    local core_envs=("ubuntu22" "debian12" "centos9" "alpine" "macos")
    
    for env in "${core_envs[@]}"; do
        run_tests_in_env "$env" "$HOST_ARCH_TYPE"
    done
    
    echo -e "${GREEN}All tests completed!${NC}"
}

# Cleanup function
cleanup() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🧹 Cleaning up HNM Docker environments...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # First, show what will be cleaned
    local hnm_images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "^hnm-")
    local hnm_containers=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "hnm-")
    
    if [ -n "$hnm_images" ]; then
        echo -e "${YELLOW}📦 Found HNM images to remove:${NC}"
        echo "$hnm_images"
        echo ""
    fi
    
    if [ -n "$hnm_containers" ]; then
        echo -e "${YELLOW}📋 Found HNM containers to remove:${NC}"
        echo "$hnm_containers"
        echo ""
    fi
    
    # Check for dangling images
    local dangling_images=$(docker images -f "dangling=true" -q)
    if [ -n "$dangling_images" ]; then
        echo -e "${YELLOW}🗑️  Found dangling images (failed builds)${NC}"
        echo ""
    fi
    
    if [ -z "$hnm_images" ] && [ -z "$hnm_containers" ] && [ -z "$dangling_images" ]; then
        echo -e "${GREEN}✅ No HNM Docker resources found to clean up${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Do you want to proceed with cleanup? (y/N)${NC}"
    read -p "Confirm: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
        return 0
    fi
    
    local cleaned_count=0
    
    # Stop and remove HNM containers
    echo -e "${BLUE}🛑 Stopping and removing HNM containers...${NC}"
    for container in $(docker ps -aq --filter "name=hnm-"); do
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
        ((cleaned_count++))
    done
    
    # Remove HNM images
    echo -e "${BLUE}🗂️  Removing HNM images...${NC}"
    for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^hnm-"); do
        docker rmi "$image" 2>/dev/null || true
        ((cleaned_count++))
    done
    
    # Clean up dangling images
    if [ -n "$dangling_images" ]; then
        echo -e "${BLUE}🧹 Removing dangling images...${NC}"
        docker image prune -f >/dev/null 2>&1 || true
        ((cleaned_count++))
    fi
    
    # Clean up any remaining build cache
    echo -e "${BLUE}🗄️  Cleaning build cache...${NC}"
    docker buildx prune -f >/dev/null 2>&1 || true
    
    echo ""
    echo -e "${GREEN}✅ Cleanup completed! Removed/cleaned $cleaned_count items${NC}"
    
    # Show disk space freed
    echo -e "${BLUE}💾 Running system cleanup...${NC}"
    docker system df
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Interactive OS selection with numbered menus
interactive_build() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎯 Interactive OS & Architecture Selection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Resource usage warning
    echo -e "${YELLOW}⚠️  Resource Usage Notice:${NC}"
    echo -e "  ${BLUE}•${NC} Each container: ~500MB disk space"
    echo -e "  ${BLUE}•${NC} Build time: 2-5 minutes per environment"
    echo -e "  ${BLUE}•${NC} Runtime memory: 512MB-1GB per container"
    echo -e "  ${BLUE}•${NC} Docker Desktop required (4GB+ free space)"
    echo -e ""
    echo -e "${GREEN}💡 This simulates fresh OS installations for testing${NC}"
    echo ""
    
    # OS Selection Menu
    echo -e "${YELLOW}📱 Select Operating System:${NC}"
    echo ""
    echo -e "${BLUE}Popular Linux Distributions:${NC}"
    echo -e "  ${GREEN}1)${NC} Ubuntu 20.04 LTS"
    echo -e "  ${GREEN}2)${NC} Ubuntu 22.04 LTS ${YELLOW}(Most Popular)${NC}"
    echo -e "  ${GREEN}3)${NC} Ubuntu 24.04 LTS ${YELLOW}(Latest)${NC}"
    echo -e "  ${GREEN}4)${NC} Debian 11 (Bullseye)"
    echo -e "  ${GREEN}5)${NC} Debian 12 (Bookworm)"
    echo ""
    echo -e "${BLUE}Enterprise & Server:${NC}"
    echo -e "  ${GREEN}6)${NC} CentOS Stream 9"
    echo -e "  ${GREEN}7)${NC} Rocky Linux 9"
    echo -e "  ${GREEN}8)${NC} Amazon Linux 2023"
    echo ""
    echo -e "${BLUE}Minimal & Specialized:${NC}"
    echo -e "  ${GREEN}9)${NC} Alpine Linux ${YELLOW}(Minimal)${NC}"
    echo -e "  ${GREEN}10)${NC} Fedora Latest"
    echo -e "  ${GREEN}11)${NC} openSUSE Leap 15"
    echo -e "  ${GREEN}12)${NC} Arch Linux"
    echo ""
    echo -e "${BLUE}Development Simulations:${NC}"
    echo -e "  ${GREEN}13)${NC} macOS Environment ${YELLOW}(Homebrew simulation)${NC}"
    echo -e "  ${GREEN}14)${NC} Windows MinGW ${YELLOW}(Git Bash simulation)${NC}"
    echo -e "  ${GREEN}15)${NC} Windows WSL ${YELLOW}(WSL simulation)${NC}"
    echo ""
    echo -e "${BLUE}Quick Options:${NC}"
    echo -e "  ${GREEN}99)${NC} All Core Environments ${YELLOW}(ubuntu22, debian12, centos9, alpine, macos)${NC}"
    echo ""
    
    # Get OS selection
    while true; do
        read -p "Choose OS (1-15, 99): " os_choice
        case $os_choice in
            1) selected_os="ubuntu20"; break ;;
            2) selected_os="ubuntu22"; break ;;
            3) selected_os="ubuntu24"; break ;;
            4) selected_os="debian11"; break ;;
            5) selected_os="debian12"; break ;;
            6) selected_os="centos9"; break ;;
            7) selected_os="rocky9"; break ;;
            8) selected_os="amazonlinux"; break ;;
            9) selected_os="alpine"; break ;;
            10) selected_os="fedora"; break ;;
            11) selected_os="opensuse"; break ;;
            12) selected_os="archlinux"; break ;;
            13) selected_os="macos"; break ;;
            14) selected_os="mingw"; break ;;
            15) selected_os="wsl"; break ;;
            99) 
                echo -e "${GREEN}🏗️  Building all core environments...${NC}"
                build_all_environments
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1-15 or 99.${NC}"
                continue
                ;;
        esac
    done
    
    echo ""
    echo -e "${GREEN}✅ Selected: $selected_os${NC}"
    echo ""
    
    # Architecture Selection Menu
    echo -e "${YELLOW}🏗️  Select Architecture:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} amd64 (x86_64) ${YELLOW}[Intel/AMD processors]${NC}"
    echo -e "  ${GREEN}2)${NC} arm64 (Apple Silicon) ${YELLOW}[M1/M2/M3 Macs, ARM servers]${NC}"
    echo -e "  ${GREEN}3)${NC} arm (ARM v7) ${YELLOW}[Raspberry Pi, embedded devices]${NC}"
    echo ""
    echo -e "${BLUE}💡 Your system: $(uname -m) ${YELLOW}(Recommended: $HOST_ARCH_TYPE)${NC}"
    echo ""
    
    # Get architecture selection
    while true; do
        read -p "Choose architecture (1-3) [2 for your Apple Silicon]: " arch_choice
        arch_choice=${arch_choice:-2}  # Default to arm64 for Apple Silicon
        case $arch_choice in
            1) selected_arch="amd64"; break ;;
            2) selected_arch="arm64"; break ;;
            3) selected_arch="arm"; break ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1, 2, or 3.${NC}"
                continue
                ;;
        esac
    done
    
    echo ""
    echo -e "${GREEN}✅ Selected: $selected_arch${NC}"
    echo ""
    
    # Confirmation
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 Build Summary:${NC}"
    echo -e "  ${BLUE}OS:${NC} $selected_os"
    echo -e "  ${BLUE}Architecture:${NC} $selected_arch"
    echo -e "  ${BLUE}Container Name:${NC} hnm-${selected_os}-${selected_arch}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Proceed with build? (Y/n): " confirm
    confirm=${confirm:-Y}
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}🚀 Starting build...${NC}"
        setup_qemu
        build_environment "$selected_os" "$selected_arch"
    else
        echo -e "${YELLOW}❌ Build cancelled${NC}"
    fi
}

# Quick selection for power users (bypass menus)
quick_select() {
    local os_num=$1
    local arch_num=$2
    
    # Map OS numbers to names
    case $os_num in
        1) local os="ubuntu20" ;;
        2) local os="ubuntu22" ;;
        3) local os="ubuntu24" ;;
        4) local os="debian11" ;;
        5) local os="debian12" ;;
        6) local os="centos9" ;;
        7) local os="rocky9" ;;
        8) local os="amazonlinux" ;;
        9) local os="alpine" ;;
        10) local os="fedora" ;;
        11) local os="opensuse" ;;
        12) local os="archlinux" ;;
        13) local os="macos" ;;
        14) local os="mingw" ;;
        15) local os="wsl" ;;
        *) echo -e "${RED}❌ Invalid OS number: $os_num (use 1-15)${NC}"; return 1 ;;
    esac
    
    # Map architecture numbers to names
    case $arch_num in
        1) local arch="amd64" ;;
        2) local arch="arm64" ;;
        3) local arch="arm" ;;
        "") local arch="$HOST_ARCH_TYPE" ;;  # Default to host arch
        *) echo -e "${RED}❌ Invalid architecture number: $arch_num (use 1-3)${NC}"; return 1 ;;
    esac
    
    echo -e "${GREEN}🚀 Quick selecting: $os ($arch)${NC}"
    setup_qemu
    build_environment "$os" "$arch"
}

# Detect if we're running inside a container
detect_container_environment() {
    local inside_docker=false
    local nesting_level=0
    
    # Check various indicators we're in a container
    if [ -f /.dockerenv ] || \
       [ -n "${DOCKER_CONTAINER:-}" ] || \
       grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        inside_docker=true
    fi
    
    # Count nesting level from environment
    nesting_level=${DOCKER_NESTING_LEVEL:-0}
    
    echo "$inside_docker:$nesting_level"
}

# Add Docker-in-Docker testing option
add_docker_in_docker_testing() {
    local container_info=$(detect_container_environment)
    local inside_docker=$(echo "$container_info" | cut -d: -f1)
    local nesting_level=$(echo "$container_info" | cut -d: -f2)
    
    if [ "$inside_docker" = "true" ]; then
        echo -e "${YELLOW}🐳 Docker-in-Docker Environment Detected${NC}"
        echo -e "  ${BLUE}Current nesting level: $nesting_level${NC}"
        echo -e "  ${BLUE}Running inside: $(cat /etc/hostname 2>/dev/null || echo 'container')${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}Advanced Option:${NC}"
    echo -e "  ${GREEN}16)${NC} Docker-in-Docker Testing ${YELLOW}(Test HNM + Docker integration)${NC}"
    
    if [ "$nesting_level" -gt 2 ]; then
        echo -e "  ${RED}⚠️  Warning: Deep nesting detected (Level $nesting_level)${NC}"
        echo -e "  ${YELLOW}🌀 Entering the Docker Inception Zone...${NC}"
    fi
    
    echo ""
}

# Help function
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  HNM Multi-OS Testing Environments${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}COMMANDS:${NC}"
    echo -e "  ${BLUE}build${NC}                    Build all core environments"
    echo -e "  ${BLUE}build <os> [arch]${NC}        Build specific OS environment"
    echo -e "  ${BLUE}test${NC}                     Run tests in all environments"
    echo -e "  ${BLUE}test <os> [arch]${NC}         Run tests in specific environment"
    echo -e "  ${BLUE}clean${NC}                    Clean up all containers and images"
    echo -e "  ${BLUE}interactive${NC}              📱 Interactive numbered menus (recommended)"
    echo -e "  ${BLUE}quick <os#> [arch#]${NC}      🚀 Quick select by number (power users)"
    echo -e "  ${BLUE}show-os${NC}                  Show available operating systems"
    echo -e "  ${BLUE}list${NC}                     List existing HNM Docker images"
    echo -e ""
    echo -e "${YELLOW}FLAGS:${NC}"
    echo -e "  ${BLUE}--force, -f${NC}              Force rebuild existing images"
    echo -e ""
    echo -e "When you run 'build' without arguments, it builds these core environments:"
    echo -e "  Ubuntu 22.04 LTS (Most common)"
    echo -e "  Debian 12 (Stable alternative)"
    echo -e "  CentOS Stream 9 (Enterprise Linux)"
    echo -e "  Alpine Linux (Minimal/container-optimized)"
    echo -e "  macOS simulation (Development environment)"
    echo -e ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo -e "  ${BLUE}hnm docker interactive${NC}        # 📱 User-friendly menus"
    echo -e "  ${BLUE}hnm docker quick 2 2${NC}          # 🚀 Ubuntu 22.04 ARM64"
    echo -e "  ${BLUE}hnm docker quick 9 1${NC}          # 🚀 Alpine Linux AMD64"
    echo -e "  ${BLUE}hnm docker build ubuntu22${NC}    # Traditional method"
    echo -e "  ${BLUE}hnm docker build alpine arm64${NC} # Traditional with arch"
    echo -e "  ${BLUE}hnm docker build --force${NC}      # Rebuild all core"
    echo -e "  ${BLUE}hnm docker test debian12${NC}      # Test specific OS"
    echo -e "  ${BLUE}hnm docker list${NC}               # See what's built"
    echo -e ""
    echo -e "${YELLOW}QUICK REFERENCE (for 'quick' command):${NC}"
    echo -e "${BLUE}OS Numbers:${NC}"
    echo -e "  1=Ubuntu20  2=Ubuntu22  3=Ubuntu24  4=Debian11   5=Debian12"
    echo -e "  6=CentOS9   7=Rocky9    8=Amazon    9=Alpine     10=Fedora"
    echo -e "  11=openSUSE 12=Arch     13=macOS    14=MinGW     15=WSL"
    echo -e "${BLUE}Architecture Numbers:${NC}"
    echo -e "  1=amd64     2=arm64     3=arm"
    echo -e ""
    echo -e "${YELLOW}SUPPORTED OS:${NC}"
    echo -e "  Ubuntu, Debian, CentOS, Rocky Linux, Alpine, Fedora,"
    echo -e "  openSUSE, Arch Linux, Amazon Linux"
    echo -e ""
    echo -e "${YELLOW}SPECIALIZED ENVIRONMENTS:${NC}"
    echo -e "  macOS simulation, MinGW/Git Bash simulation, WSL simulation"
    echo -e ""
    echo -e "${YELLOW}ARCHITECTURES:${NC}"
    echo -e "  amd64 (x86_64), arm64 (Apple Silicon), arm (ARM v7)"
    echo -e ""
    echo -e "${YELLOW}IMAGE MANAGEMENT:${NC}"
    echo -e "  • Existing images are detected automatically"
    echo -e "  • Use ${BLUE}list${NC} to see all HNM Docker images"
    echo -e "  • Use ${BLUE}--force${NC} to rebuild existing images"
    echo -e "  • Interactive prompts when images exist"
    echo -e ""
    echo -e "${GREEN}💡 For simple installation, use: hnm setup${NC}"
    echo -e "${BLUE}🎯 Best for beginners: hnm docker interactive${NC}"
    echo -e "${BLUE}🚀 Best for power users: hnm docker quick 2 2${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main function
main() {
    local command="$1"
    local force_rebuild=false
    
    # Check for --force flag in arguments
    for arg in "$@"; do
        if [ "$arg" = "--force" ] || [ "$arg" = "-f" ]; then
            force_rebuild=true
            # Remove the flag from arguments
            set -- "${@/$arg/}"
            break
        fi
    done
    
    case "$command" in
        build)
            if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
                force_rebuild=true
                shift  # Remove the flag
            fi
            
            if [[ -n "$2" ]]; then
                setup_qemu
                build_environment "$2" "$3" "$force_rebuild"
            else
                build_all_environments "$force_rebuild"
            fi
            ;;
        test)
            if [[ -n "$2" ]]; then
                run_tests_in_env "$2" "$3"
            else
                run_all_tests
            fi
            ;;
        clean)
            cleanup
            ;;
        interactive)
            interactive_build
            ;;
        quick)
            if [[ -n "$2" && -n "$3" ]]; then
                quick_select "$2" "$3"
            else
                echo -e "${YELLOW}Usage: $0 quick <os_number> <arch_number>${NC}"
                echo -e ""
                echo -e "${BLUE}📋 Quick Reference:${NC}"
                echo -e "${GREEN}Popular OS Numbers:${NC}"
                echo -e "  2 = Ubuntu 22.04 LTS (most popular)"
                echo -e "  9 = Alpine Linux (minimal)"
                echo -e "  13 = macOS simulation"
                echo -e ""
                echo -e "${GREEN}Architecture Numbers:${NC}"
                echo -e "  1 = amd64 (Intel/AMD)"
                echo -e "  2 = arm64 (Apple Silicon) ← Your system"
                echo -e "  3 = arm (Raspberry Pi)"
                echo -e ""
                echo -e "${YELLOW}Examples:${NC}"
                echo -e "  ${BLUE}$0 quick 2 2${NC}  # Ubuntu 22.04 on Apple Silicon"
                echo -e "  ${BLUE}$0 quick 9 1${NC}  # Alpine Linux on Intel/AMD"
                echo -e "  ${BLUE}$0 quick 13 2${NC} # macOS simulation on Apple Silicon"
                echo -e ""
                echo -e "${GREEN}💡 For full menu: $0 interactive${NC}"
                echo -e "${BLUE}📖 All options: $0 help${NC}"
            fi
            ;;
        show-os)
            show_os_menu
            ;;
        list)
            show_existing_images
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${YELLOW}Usage: $0 {build|test|clean|interactive|quick|show-os|list|help} [options]${NC}"
            echo -e "  build [os] [arch] [--force] - Build environments (all core or specific)"
            echo -e "  test [os] [arch]            - Run tests (all or specific)"
            echo -e "  clean                       - Clean up containers and images"
            echo -e "  interactive                 - 📱 User-friendly numbered menus"
            echo -e "  quick <os#> <arch#>         - 🚀 Quick select (e.g., quick 2 2)"
            echo -e "  show-os                     - Show available operating systems"
            echo -e "  list                        - List existing HNM Docker images"
            echo -e "  help                        - Show detailed help"
            echo -e ""
            echo -e "${YELLOW}Flags:${NC}"
            echo -e "  --force, -f                 - Force rebuild existing images"
            echo -e ""
            echo -e "${GREEN}🎯 Recommended: $0 interactive${NC}"
            echo -e "${BLUE}🚀 Power users: $0 quick 2 2${NC}"
            echo -e "${BLUE}📖 Full help: $0 help${NC}"
            return 1
            ;;
    esac
}

# Run main function
main "$@" 