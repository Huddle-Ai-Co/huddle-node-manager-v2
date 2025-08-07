#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Function to determine installation paths based on device
determine_installation_paths() {
    local os=$(detect_os)
    local is_root_user=$(is_root && echo "true" || echo "false")
    
    echo -e "${BLUE}🔍 Detecting device and installation paths...${NC}"
    echo -e "${BLUE}OS: $os${NC}"
    echo -e "${BLUE}Running as root: $is_root_user${NC}"
    
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
                echo -e "${RED}❌ Unsupported operating system: $os${NC}"
                exit 1
                ;;
        esac
        INSTALL_TYPE="user"
    fi
    
    # Runtime directories (same across all platforms)
    HNM_HOME="$HOME/.hnm"
    HNM_PRODUCTION_ROOT="$HOME/.huddle-node-manager"
    
    echo -e "${BLUE}Installation Type: $INSTALL_TYPE${NC}"
    echo -e "${BLUE}Library Directory: $HNM_LIB_DIR${NC}"
    echo -e "${BLUE}Documentation Directory: $HNM_DOC_DIR${NC}"
    echo -e "${BLUE}Config Directory: $HNM_CONFIG_DIR${NC}"
    echo -e "${BLUE}Production Root: $HNM_PRODUCTION_ROOT${NC}"
}

# Function to check for existing installation
check_existing_installation() {
    echo -e "${YELLOW}🔍 Checking for existing HNM installation...${NC}"
    
    local existing_installations=()
    
    # Check for existing directories
    if [ -d "$HNM_LIB_DIR" ]; then
        existing_installations+=("Library: $HNM_LIB_DIR")
    fi
    
    if [ -d "$HNM_PRODUCTION_ROOT" ]; then
        existing_installations+=("Production: $HNM_PRODUCTION_ROOT")
    fi
    
    if [ -d "$HNM_CONFIG_DIR" ]; then
        existing_installations+=("Config: $HNM_CONFIG_DIR")
    fi
    
    if [ -d "$HNM_HOME" ]; then
        existing_installations+=("Home: $HNM_HOME")
    fi
    
    if [ ${#existing_installations[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Found existing HNM installation:${NC}"
        for install in "${existing_installations[@]}"; do
            echo -e "  ${YELLOW}• $install${NC}"
        done
        
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo -e "  1) Continue with new installation (will overwrite existing files)"
        echo -e "  2) Backup existing installation and continue"
        echo -e "  3) Exit and handle existing installation manually"
        echo ""
        read -p "Choose option (1-3): " -n 1 -r
        echo ""
        
        case $REPLY in
            1)
                echo -e "${YELLOW}⚠️  Proceeding with overwrite...${NC}"
                ;;
            2)
                echo -e "${BLUE}📦 Creating backup of existing installation...${NC}"
                local backup_dir="$HOME/.huddle-node-manager-backup-$(date +%Y%m%d-%H%M%S)"
                mkdir -p "$backup_dir"
                
                if [ -d "$HNM_LIB_DIR" ]; then
                    cp -r "$HNM_LIB_DIR" "$backup_dir/"
                fi
                if [ -d "$HNM_PRODUCTION_ROOT" ]; then
                    cp -r "$HNM_PRODUCTION_ROOT" "$backup_dir/"
                fi
                if [ -d "$HNM_CONFIG_DIR" ]; then
                    cp -r "$HNM_CONFIG_DIR" "$backup_dir/"
                fi
                if [ -d "$HNM_HOME" ]; then
                    cp -r "$HNM_HOME" "$backup_dir/"
                fi
                
                echo -e "${GREEN}✅ Backup created at: $backup_dir${NC}"
                ;;
            3)
                echo -e "${YELLOW}Installation cancelled. Please handle existing installation manually.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Exiting.${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}✅ No existing installation found${NC}"
    fi
}

# Function to clean up macOS metadata
cleanup_macos_metadata() {
    echo -e "${BLUE}🧹 Cleaning up macOS metadata files...${NC}"
    
    # Remove __MACOSX directories
    find "$HNM_LIB_DIR" -name "__MACOSX" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$HNM_PRODUCTION_ROOT" -name "__MACOSX" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove .DS_Store files
    find "$HNM_LIB_DIR" -name ".DS_Store" -type f -delete 2>/dev/null || true
    find "$HNM_PRODUCTION_ROOT" -name ".DS_Store" -type f -delete 2>/dev/null || true
    
    echo -e "${GREEN}✅ macOS metadata cleaned up${NC}"
}

# Header
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}HNM Distribution Initializer${NC}"
echo -e "${BLUE}=================================${NC}"

# Check if we're in the distribution directory
if [ ! -f "install-hnm-complete.sh" ]; then
    echo -e "${RED}❌ Error: This script must be run from the huddle-node-manager-distribution directory${NC}"
    echo -e "${YELLOW}Please navigate to the distribution directory and run this script${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Checking distribution package structure...${NC}"

# Check for required files
REQUIRED_FILES=(
    "install-hnm-complete.sh"
    "install-hnm.sh"
    "hnm"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "  ${RED}• $file${NC}"
    done
    exit 1
fi

echo -e "${GREEN}✅ All required files found${NC}"

# Determine installation paths based on device
determine_installation_paths

# Check for existing installation
check_existing_installation

# Create expected directory structure
echo -e "${YELLOW}📁 Creating expected directory structure...${NC}"

# Create user-local installation directories
mkdir -p "$HNM_LIB_DIR"
mkdir -p "$HNM_DOC_DIR"
mkdir -p "$HNM_CONFIG_DIR"
mkdir -p "$HNM_LIB_DIR/docker"
mkdir -p "$HNM_LIB_DIR/testing"

echo -e "${GREEN}✅ Created directory structure${NC}"

# Handle Data directory/zip
echo -e "${YELLOW}📦 Processing Data directory...${NC}"
if [ -f "Data.zip" ]; then
    echo -e "${BLUE}Extracting Data.zip to $HNM_PRODUCTION_ROOT/...${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT"
    unzip -o -q Data.zip -d "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ Data.zip extracted${NC}"
elif [ -d "Data" ]; then
    echo -e "${BLUE}Copying Data directory to $HNM_PRODUCTION_ROOT/...${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT"
    cp -r Data "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ Data directory copied${NC}"
elif [ -d "medical" ]; then
    echo -e "${BLUE}Copying medical directory to $HNM_PRODUCTION_ROOT/Data/...${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT/Data"
    cp -r medical "$HNM_PRODUCTION_ROOT/Data/"
    echo -e "${GREEN}✅ medical directory copied to Data/${NC}"
else
    echo -e "${YELLOW}⚠️  No Data.zip, Data/, or medical/ found - creating empty Data directory${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT/Data"
    echo -e "${GREEN}✅ Created empty Data directory${NC}"
fi

# Handle docker directory/zip
echo -e "${YELLOW}📦 Processing docker directory...${NC}"
if [ -f "docker.zip" ]; then
    echo -e "${BLUE}Extracting docker.zip to $HNM_LIB_DIR/docker/...${NC}"
    unzip -o -q docker.zip -d "$HNM_LIB_DIR/"
    echo -e "${GREEN}✅ docker.zip extracted${NC}"
elif [ -d "docker" ]; then
    echo -e "${BLUE}Copying docker directory to $HNM_LIB_DIR/docker/...${NC}"
    cp -r docker "$HNM_LIB_DIR/"
    echo -e "${GREEN}✅ docker directory copied${NC}"
else
    echo -e "${YELLOW}⚠️  No docker.zip or docker/ found - creating empty docker directory${NC}"
    mkdir -p "$HNM_LIB_DIR/docker"
    echo -e "${GREEN}✅ Created empty docker directory${NC}"
fi

# Handle bundled_models directory/zip
echo -e "${YELLOW}📦 Processing bundled_models directory...${NC}"
if [ -f "bundled_models.zip" ]; then
    echo -e "${BLUE}Extracting bundled_models.zip to $HNM_PRODUCTION_ROOT/...${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT"
    unzip -o -q bundled_models.zip -d "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ bundled_models.zip extracted${NC}"
elif [ -d "bundled_models" ]; then
    echo -e "${BLUE}Copying bundled_models directory to $HNM_PRODUCTION_ROOT/...${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT"
    cp -r bundled_models "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ bundled_models directory copied${NC}"
else
    echo -e "${YELLOW}⚠️  No bundled_models.zip or bundled_models/ found - creating empty bundled_models directory${NC}"
    mkdir -p "$HNM_PRODUCTION_ROOT/bundled_models"
    echo -e "${GREEN}✅ Created empty bundled_models directory${NC}"
fi

# Copy installation scripts to proper locations
echo -e "${YELLOW}📋 Copying installation scripts...${NC}"

# Copy main installation scripts to root of extracted location
cp install-hnm-complete.sh "$HNM_PRODUCTION_ROOT/"
cp install-hnm.sh "$HNM_PRODUCTION_ROOT/"
cp hnm "$HNM_PRODUCTION_ROOT/"

# Copy all scripts from scripts/ directory to $HNM_LIB_DIR/
if [ -d "scripts" ]; then
    echo -e "${BLUE}Copying scripts to $HNM_LIB_DIR/...${NC}"
    cp scripts/* "$HNM_LIB_DIR/"
    chmod +x "$HNM_LIB_DIR/"*.sh
    chmod +x "$HNM_LIB_DIR/"*.py
    echo -e "${GREEN}✅ Scripts copied and made executable${NC}"
fi

# Copy testing scripts from testing/ directory to $HNM_LIB_DIR/testing/
if [ -d "testing" ]; then
    echo -e "${BLUE}Copying testing scripts to $HNM_LIB_DIR/testing/...${NC}"
    cp testing/* "$HNM_LIB_DIR/testing/"
    chmod +x "$HNM_LIB_DIR/testing/"*.sh
    chmod +x "$HNM_LIB_DIR/testing/"*.bat 2>/dev/null || true
    echo -e "${GREEN}✅ Testing scripts copied and made executable${NC}"
fi

# Copy documentation files
if [ -d "docs" ]; then
    echo -e "${BLUE}Copying documentation to $HNM_DOC_DIR/...${NC}"
    cp -r docs/* "$HNM_DOC_DIR/"
    echo -e "${GREEN}✅ Documentation copied${NC}"
fi

# Copy configuration files
if [ -d "config" ]; then
    echo -e "${BLUE}Copying configuration to $HNM_CONFIG_DIR/...${NC}"
    cp -r config/* "$HNM_CONFIG_DIR/"
    echo -e "${GREEN}✅ Configuration copied${NC}"
fi

# Copy all other files from root to $HNM_PRODUCTION_ROOT/
echo -e "${BLUE}Copying remaining files to $HNM_PRODUCTION_ROOT/...${NC}"
cp *.sh "$HNM_PRODUCTION_ROOT/" 2>/dev/null || true
cp *.py "$HNM_PRODUCTION_ROOT/" 2>/dev/null || true
cp *.json "$HNM_PRODUCTION_ROOT/" 2>/dev/null || true
cp *.txt "$HNM_PRODUCTION_ROOT/" 2>/dev/null || true
chmod +x "$HNM_PRODUCTION_ROOT/"*.sh 2>/dev/null || true
echo -e "${GREEN}✅ All files copied${NC}"

# Copy run_hnm_script.sh to $HNM_LIB_DIR/ (it should be in the lib directory)
if [ -f "run_hnm_script.sh" ]; then
    echo -e "${BLUE}Copying run_hnm_script.sh to $HNM_LIB_DIR/...${NC}"
    cp run_hnm_script.sh "$HNM_LIB_DIR/"
    chmod +x "$HNM_LIB_DIR/run_hnm_script.sh"
    echo -e "${GREEN}✅ run_hnm_script.sh copied to lib directory${NC}"
else
    echo -e "${YELLOW}⚠️  run_hnm_script.sh not found in distribution${NC}"
fi

# Create symlink for scripts directory to avoid duplication
echo -e "${BLUE}Creating scripts symlink in $HNM_PRODUCTION_ROOT/...${NC}"
if [ -d "$HNM_LIB_DIR/scripts" ]; then
    # Remove existing scripts directory if it exists
    rm -rf "$HNM_PRODUCTION_ROOT/scripts" 2>/dev/null || true
    # Create symlink from production root to lib scripts
    ln -sf "$HNM_LIB_DIR/scripts" "$HNM_PRODUCTION_ROOT/scripts"
    echo -e "${GREEN}✅ Scripts symlink created: $HNM_PRODUCTION_ROOT/scripts -> $HNM_LIB_DIR/scripts${NC}"
else
    echo -e "${YELLOW}⚠️  Scripts directory not found in $HNM_LIB_DIR${NC}"
fi

# Copy essential server files to production root for setup scripts
echo -e "${BLUE}Copying essential server files to $HNM_PRODUCTION_ROOT/...${NC}"
if [ -f "$HNM_LIB_DIR/optimized_gguf_server.py" ]; then
    cp "$HNM_LIB_DIR/optimized_gguf_server.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ optimized_gguf_server.py copied${NC}"
fi
if [ -f "$HNM_LIB_DIR/optimized_resource_server.py" ]; then
    cp "$HNM_LIB_DIR/optimized_resource_server.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ optimized_resource_server.py copied${NC}"
fi
if [ -f "$HNM_LIB_DIR/platform_adaptive_config.py" ]; then
    cp "$HNM_LIB_DIR/platform_adaptive_config.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ platform_adaptive_config.py copied${NC}"
fi
if [ -f "$HNM_LIB_DIR/device_detection_test.py" ]; then
    cp "$HNM_LIB_DIR/device_detection_test.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ device_detection_test.py copied${NC}"
fi
if [ -f "$HNM_LIB_DIR/resource_monitor.py" ]; then
    cp "$HNM_LIB_DIR/resource_monitor.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ resource_monitor.py copied${NC}"
fi
if [ -f "$HNM_LIB_DIR/vllm_style_optimizer.py" ]; then
    cp "$HNM_LIB_DIR/vllm_style_optimizer.py" "$HNM_PRODUCTION_ROOT/"
    echo -e "${GREEN}✅ vllm_style_optimizer.py copied${NC}"
fi
chmod +x "$HNM_PRODUCTION_ROOT/"*.py 2>/dev/null || true
echo -e "${GREEN}✅ Essential server files copied to production root${NC}"

# Clean up macOS metadata
cleanup_macos_metadata

# Verify the structure
echo -e "${YELLOW}🔍 Verifying installation structure...${NC}"

EXPECTED_DIRS=(
    "$HNM_PRODUCTION_ROOT"
    "$HNM_LIB_DIR"
    "$HNM_DOC_DIR"
    "$HNM_CONFIG_DIR"
    "$HNM_LIB_DIR/docker"
    "$HNM_LIB_DIR/testing"
)

for dir in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $dir${NC}"
    else
        echo -e "${RED}❌ $dir (missing)${NC}"
    fi
done

# Check for critical files
CRITICAL_FILES=(
    "$HNM_PRODUCTION_ROOT/install-hnm-complete.sh"
    "$HNM_PRODUCTION_ROOT/install-hnm.sh"
    "$HNM_PRODUCTION_ROOT/hnm"
    "$HNM_LIB_DIR/run_hnm_script.sh"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $(basename "$file")${NC}"
    else
        echo -e "${RED}❌ $(basename "$file") (missing)${NC}"
    fi
done

echo -e "${GREEN}🎉 Distribution initialization complete!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Navigate to the installation directory:"
echo -e "     ${BLUE}cd $HNM_PRODUCTION_ROOT${NC}"
echo -e "  2. Run the complete installation:"
echo -e "     ${BLUE}./install-hnm-complete.sh${NC}"
echo -e "  3. Or run the basic installation:"
echo -e "     ${BLUE}./install-hnm.sh${NC}"
echo ""
echo -e "${CYAN}💡 The installation scripts are now ready to run from $HNM_PRODUCTION_ROOT/${NC}" 