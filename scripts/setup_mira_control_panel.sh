#!/bin/bash

# MIRA Control Panel Deployment Script
# Builds and deploys the MIRA Control Panel with microphone permission fixes
# Creates a production-ready package with only the dist folder

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}🔄 $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check for Node.js and npm
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js first."
        log_info "Visit: https://nodejs.org/"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm not found. Please install npm first."
        return 1
    fi
    
    # Check for Electron
    if ! npm list -g electron &> /dev/null; then
        log_warning "Electron not found globally. Will install locally."
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

# Find MIRA Control Panel source
find_mira_source() {
    local source_dirs=(
        "api/open-processing/mira-control-app"
        "scripts/mira-control-app"
        "../api/open-processing/mira-control-app"
        "../../api/open-processing/mira-control-app"
    )
    
    for dir in "${source_dirs[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

# Apply microphone permission fixes
apply_microphone_fixes() {
    local source_dir="$1"
    log_step "Applying microphone permission fixes..."
    
    # Store current directory
    local current_dir=$(pwd)
    
    cd "$source_dir" || {
        log_error "Failed to navigate to source directory: $source_dir"
        return 1
    }
    
    # Check if fixes are already applied
    if grep -q "NSCameraUseContinuityCameraDeviceType" package.json; then
        log_success "Microphone permission fixes already applied"
        cd "$current_dir"
        return 0
    fi
    
    # Backup original package.json
    cp package.json package.json.backup
    
    # Update package.json with microphone fixes
    log_info "Updating package.json with microphone permission fixes..."
    
    # Create a temporary file with the fixes
    cat > package.json.fixed << 'EOL'
{
  "name": "mira-control-panel",
  "version": "1.0.0",
  "description": "MIRA Medical AI Assistant Control Panel",
  "main": "main.js",
  "scripts": {
    "start": "electron .",
    "dev": "electron . --dev",
    "build": "electron-builder",
    "pack": "electron-builder --dir",
    "dist": "electron-builder",
    "build:mac": "electron-builder --mac"
  },
  "keywords": [
    "mira",
    "medical",
    "ai",
    "assistant",
    "control-panel",
    "electron"
  ],
  "author": "MIRA Team",
  "license": "MIT",
  "devDependencies": {
    "electron": "^28.0.0",
    "electron-builder": "^24.0.0"
  },
  "dependencies": {
    "chokidar": "^3.5.3"
  },
  "build": {
    "appId": "com.mira.control-panel",
    "productName": "MIRA Control Panel",
    "directories": {
      "output": "dist"
    },
    "files": [
      "main.js",
      "index.html",
      "*.png",
      "*.md",
      "node_modules/**/*"
    ],
    "mac": {
      "category": "public.app-category.medical",
      "identity": null,
      "extendInfo": {
        "NSMicrophoneUsageDescription": "This app needs microphone access for voice control and live transcription.",
        "NSSpeechRecognitionUsageDescription": "This app needs speech recognition for voice commands and live transcription.",
        "NSCameraUseContinuityCameraDeviceType": true
      },
      "hardenedRuntime": true,
      "entitlements": "entitlements.mac.plist",
      "entitlementsInherit": "entitlements.mac.plist"
    },
    "win": {
      "target": "nsis"
    },
    "linux": {
      "target": "AppImage"
    }
  }
}
EOL
    
    # Replace the original package.json
    mv package.json.fixed package.json
    
    # Create entitlements file
    log_info "Creating entitlements.mac.plist..."
    cat > entitlements.mac.plist << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.device.audio-output</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
  </dict>
</plist>
EOL
    
    log_success "Microphone permission fixes applied"
    cd "$current_dir"
}

# Build the Electron app
build_mira_control_panel() {
    local source_dir="$1"
    log_step "Building MIRA Control Panel..."
    
    # Store current directory
    local current_dir=$(pwd)
    
    cd "$source_dir" || {
        log_error "Failed to navigate to source directory: $source_dir"
        return 1
    }
    
    # Install dependencies
    log_info "Installing npm dependencies..."
    npm install
    
    if [ $? -ne 0 ]; then
        log_error "npm install failed"
        cd "$current_dir"
        return 1
    fi
    
    # Build for macOS
    log_info "Building for macOS..."
    npm run build:mac
    
    if [ $? -ne 0 ]; then
        log_error "Build failed"
        cd "$current_dir"
        return 1
    fi
    
    log_success "MIRA Control Panel built successfully"
    cd "$current_dir"
}

# Create production package
create_production_package() {
    local source_dir="$1"
    local target_dir="$2"
    log_step "Creating production package..."
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Copy only the dist folder and essential files
    if [ -d "$source_dir/dist" ]; then
        cp -r "$source_dir/dist" "$target_dir/"
        log_success "Copied dist folder to production package"
    else
        log_error "dist folder not found in source"
        return 1
    fi
    
    # Copy README and documentation
    if [ -f "$source_dir/README.md" ]; then
        cp "$source_dir/README.md" "$target_dir/"
    fi
    
    if [ -f "$source_dir/MICROPHONE_FIX_README.md" ]; then
        cp "$source_dir/MICROPHONE_FIX_README.md" "$target_dir/"
    fi
    
    # Create launch script
    cat > "$target_dir/launch_mira_control_panel.sh" << 'EOL'
#!/bin/bash

# MIRA Control Panel Launcher
# Launches the built MIRA Control Panel with microphone permission fixes

echo "🚀 Launching MIRA Control Panel with Microphone Permission Fixes"
echo "================================================================"

# Find the app in the dist folder
if [ -d "dist/mac-arm64/MIRA Control Panel.app" ]; then
    echo "✅ Found MIRA Control Panel app"
    echo ""
    echo "🔧 Microphone permission fixes applied:"
    echo "   • NSCameraUseContinuityCameraDeviceType = true"
    echo "   • NSMicrophoneUsageDescription configured"
    echo "   • NSSpeechRecognitionUsageDescription configured"
    echo "   • Enhanced audio constraints"
    echo "   • Proper entitlements"
    echo ""
    echo "🎤 Microphone permissions should work without warnings"
    echo ""
    
    # Launch the app
    open "dist/mac-arm64/MIRA Control Panel.app"
    
    echo "✅ App launched!"
    echo ""
    echo "💡 If you still see AVCaptureDeviceTypeExternal warnings:"
    echo "   1. Close the app completely"
    echo "   2. Check System Preferences > Security & Privacy > Microphone"
    echo "   3. Ensure MIRA Control Panel has microphone access"
    
else
    echo "❌ MIRA Control Panel app not found in dist/mac-arm64/"
    echo "Please run the build script first: ./setup_mira_control_panel.sh"
    exit 1
fi
EOL
    
    chmod +x "$target_dir/launch_mira_control_panel.sh"
    
    # Create verification script
    cat > "$target_dir/verify_microphone_fixes.sh" << 'EOL'
#!/bin/bash

# Verify Microphone Permission Fixes
# Checks if the AVCaptureDeviceTypeExternal warnings are fixed

echo "🔍 Verifying Microphone Permission Fixes"
echo "========================================"

# Check if the app exists
if [ ! -d "dist/mac-arm64/MIRA Control Panel.app" ]; then
    echo "❌ MIRA Control Panel app not found"
    exit 1
fi

# Check Info.plist for fixes
echo "📋 Checking Info.plist for microphone permission fixes..."

if grep -q "NSCameraUseContinuityCameraDeviceType" "dist/mac-arm64/MIRA Control Panel.app/Contents/Info.plist"; then
    echo "✅ NSCameraUseContinuityCameraDeviceType found in Info.plist"
else
    echo "❌ NSCameraUseContinuityCameraDeviceType not found in Info.plist"
fi

if grep -q "NSMicrophoneUsageDescription" "dist/mac-arm64/MIRA Control Panel.app/Contents/Info.plist"; then
    echo "✅ NSMicrophoneUsageDescription found in Info.plist"
else
    echo "❌ NSMicrophoneUsageDescription not found in Info.plist"
fi

if grep -q "NSSpeechRecognitionUsageDescription" "dist/mac-arm64/MIRA Control Panel.app/Contents/Info.plist"; then
    echo "✅ NSSpeechRecognitionUsageDescription found in Info.plist"
else
    echo "❌ NSSpeechRecognitionUsageDescription not found in Info.plist"
fi

echo ""
echo "🎯 To test the fixes:"
echo "   1. Run: ./launch_mira_control_panel.sh"
echo "   2. Check for AVCaptureDeviceTypeExternal warnings in console"
echo "   3. Test microphone permissions in the app"
EOL
    
    chmod +x "$target_dir/verify_microphone_fixes.sh"
    
    log_success "Production package created in: $target_dir"
}

# Main function
main() {
    echo -e "${PURPLE}🎤 MIRA Control Panel Deployment Script${NC}"
    echo -e "${CYAN}Builds production-ready package with microphone permission fixes${NC}"
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Find source directory - simplified approach
    log_step "Finding MIRA Control Panel source..."
    local source_dir=""
    
    if [ -d "../api/open-processing/mira-control-app" ] && [ -f "../api/open-processing/mira-control-app/package.json" ]; then
        source_dir="../api/open-processing/mira-control-app"
        log_success "Found MIRA Control Panel source in: $source_dir"
    elif [ -d "scripts/mira-control-app" ] && [ -f "scripts/mira-control-app/package.json" ]; then
        source_dir="scripts/mira-control-app"
        log_success "Found MIRA Control Panel source in: $source_dir"
    else
        log_error "MIRA Control Panel source not found"
        log_info "Expected locations:"
        log_info "  • ../api/open-processing/mira-control-app"
        log_info "  • scripts/mira-control-app"
        exit 1
    fi
    
    # Apply microphone fixes
    if ! apply_microphone_fixes "$source_dir"; then
        exit 1
    fi
    
    # Build the app
    if ! build_mira_control_panel "$source_dir"; then
        exit 1
    fi
    
    # Create production package
    local target_dir="mira-control-panel-production"
    if ! create_production_package "$source_dir" "$target_dir"; then
        exit 1
    fi
    
    echo ""
    log_success "🎉 MIRA Control Panel deployment completed!"
    echo ""
    log_info "📦 Production package created in: $target_dir"
    echo ""
    log_info "🚀 To launch the app:"
    echo "   cd $target_dir"
    echo "   ./launch_mira_control_panel.sh"
    echo ""
    log_info "🔍 To verify the fixes:"
    echo "   cd $target_dir"
    echo "   ./verify_microphone_fixes.sh"
    echo ""
    log_info "✨ Features included:"
    echo "   • Fixed AVCaptureDeviceTypeExternal deprecation warnings"
    echo "   • Enhanced microphone permissions"
    echo "   • Proper entitlements for macOS"
    echo "   • High-quality Lucide SVG icons (replaced emojis)"
    echo "   • NextJS-style modern UI design"
    echo "   • Enhanced animations and transitions"
    echo "   • Production-ready package (dist folder only)"
    echo ""
    log_success "🌟 Your MIRA Control Panel is ready for deployment!"
}

# Run main function
main "$@" 