#!/bin/bash

# HNM Release Builder
# Builds and tests self-extracting installers

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 HNM Release Builder${NC}"
echo ""

# Parse command line arguments
BUILD_ONLY=false
TEST_ONLY=false
CLEAN=false
INCLUDE_DATA=false
INCLUDE_SAMPLE_DATA=false
MINIMAL_BUILD=false

while [ $# -gt 0 ]; do
    case "$1" in
        --build-only)
            BUILD_ONLY=true
            ;;
        --test-only)
            TEST_ONLY=true
            ;;
        --clean)
            CLEAN=true
            ;;
        --include-data)
            INCLUDE_DATA=true
            ;;
        --include-sample-data)
            INCLUDE_SAMPLE_DATA=true
            ;;
        --minimal)
            MINIMAL_BUILD=true
            ;;
        --help|-h)
            echo "HNM Release Builder"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --build-only          Build installer only"
            echo "  --test-only           Test existing installer only"
            echo "  --clean               Clean previous builds"
            echo "  --include-data        Include full Data/ directory (~2-5GB)"
            echo "  --include-sample-data Include sample files from Data/"
            echo "  --minimal             Minimal build (core files only)"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Build Types:"
            echo "  Standard (default):   ~50-200MB with api/, scripts/, docs/, models/"
            echo "  Minimal:              ~5-20MB with core files only"
            echo "  Sample Data:          +~10-50MB with sample files"
            echo "  Full Data:            +~2-5GB with complete Data/ directory"
            exit 0
            ;;
    esac
    shift
done

# Clean previous builds
if [ "$CLEAN" = "true" ]; then
    echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
    rm -f huddle-node-manager-v*-installer*.run
    echo -e "${GREEN}✓ Cleaned${NC}"
    echo ""
fi

# Build installer
if [ "$TEST_ONLY" = "false" ]; then
    echo -e "${BLUE}📦 Building self-extracting installer...${NC}"
    
    # Build command with options
    BUILD_CMD="./create-self-extracting-installer.sh"
    if [ "$INCLUDE_DATA" = "true" ]; then
        BUILD_CMD="$BUILD_CMD --include-data"
    fi
    if [ "$INCLUDE_SAMPLE_DATA" = "true" ]; then
        BUILD_CMD="$BUILD_CMD --include-sample-data"
    fi
    if [ "$MINIMAL_BUILD" = "true" ]; then
        BUILD_CMD="$BUILD_CMD --minimal"
    fi
    
    echo -e "${YELLOW}Running: $BUILD_CMD${NC}"
    $BUILD_CMD
    echo ""
fi

# Test installer
if [ "$BUILD_ONLY" = "false" ]; then
    echo -e "${BLUE}🧪 Testing installer...${NC}"
    
    # Find the latest installer
    INSTALLER=$(ls huddle-node-manager-v*-installer.run | head -1)
    
    if [ ! -f "$INSTALLER" ]; then
        echo -e "${RED}❌ No installer found to test${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Testing: $INSTALLER${NC}"
    
    # Test extraction only
    echo ""
    echo -e "${BLUE}📤 Testing extraction...${NC}"
    ./"$INSTALLER" --extract-only --target-dir test-extract
    
    if [ -d "test-extract" ] && [ -f "test-extract/install-hnm.sh" ]; then
        echo -e "${GREEN}✓ Extraction test passed${NC}"
        rm -rf test-extract
    else
        echo -e "${RED}❌ Extraction test failed${NC}"
        exit 1
    fi
    
    # Test help
    echo ""
    echo -e "${BLUE}📖 Testing help...${NC}"
    ./"$INSTALLER" --help
    
    echo ""
    echo -e "${GREEN}✅ All tests passed!${NC}"
fi

echo ""
echo -e "${PURPLE}🎉 Release Build Complete!${NC}"
echo ""
echo -e "${YELLOW}📦 Generated Files:${NC}"
ls -lh huddle-node-manager-v*-installer*.run

echo ""
echo -e "${BLUE}📊 Build Summary:${NC}"
for file in huddle-node-manager-v*-installer*.run; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        case "$file" in
            *minimal*)
                echo -e "  🔹 ${file} (${size}) - Core files only"
                ;;
            *full*)
                echo -e "  🔸 ${file} (${size}) - Complete package with Data/"
                ;;
            *sample*)
                echo -e "  🔹 ${file} (${size}) - Standard + sample data"
                ;;
            *)
                echo -e "  🔹 ${file} (${size}) - Standard package"
                ;;
        esac
    fi
done

echo ""
echo -e "${BLUE}🚀 Ready for Distribution!${NC}"
echo ""
echo -e "${YELLOW}Usage for end users:${NC}"
echo "  1. Download the .run file"
echo "  2. chmod +x huddle-node-manager-v*-installer.run"
echo "  3. ./huddle-node-manager-v*-installer.run"
echo ""
echo -e "${GREEN}✨ That's it! One file, auto-installs! ✨${NC}" 