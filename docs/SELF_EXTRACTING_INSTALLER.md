# 🚀 HNM Self-Extracting Installer

## Overview

The HNM Self-Extracting Installer creates a **single executable file** that contains the entire Huddle Node Manager installation package. When users run this file, it automatically extracts and installs HNM with zero additional steps.

## ✨ Benefits

### For Users:
- ✅ **One-click installation** - Download and run, that's it!
- ✅ **No dependencies** - No need for git, tar, or unzip
- ✅ **Automatic extraction** - Files extracted and installer runs immediately
- ✅ **Flexible options** - Extract-only, custom directories, manual control
- ✅ **Cross-platform** - Works on macOS, Linux, Windows/WSL

### For Developers:
- ✅ **Simple distribution** - One file to upload/host
- ✅ **Reduced support** - Fewer "how to install" questions
- ✅ **Professional appearance** - Enterprise-grade installer experience
- ✅ **Version control** - Clear versioning in filename

## 🏗️ Building the Installer

### Quick Build
```bash
# Build and test installer
./build-release.sh

# Build only (no testing)
./build-release.sh --build-only

# Clean previous builds and rebuild
./build-release.sh --clean
```

### Manual Build
```bash
# Create the self-extracting installer
./create-self-extracting-installer.sh
```

## 📦 Generated Files

Running the build creates these files:

```
huddle-node-manager-v2.0.0-installer.run         # Auto-installs when run
huddle-node-manager-v2.0.0-installer-extract-only.run  # Extracts files only
```

**File Size**: Typically 50-200MB depending on included components
- Core HNM: ~5MB
- API components: ~20-50MB  
- ML models: ~100-150MB (if included)

## 🚀 Usage Examples

### For End Users

#### Basic Installation (Recommended)
```bash
# Download and run (auto-installs)
chmod +x huddle-node-manager-v2.0.0-installer.run
./huddle-node-manager-v2.0.0-installer.run
```

#### Advanced Options
```bash
# Extract files only (no auto-install)
./huddle-node-manager-v2.0.0-installer.run --extract-only

# Extract to specific directory
./huddle-node-manager-v2.0.0-installer.run --target-dir /opt/hnm

# Extract but don't auto-install (manual control)
./huddle-node-manager-v2.0.0-installer.run --no-auto-install

# Show help
./huddle-node-manager-v2.0.0-installer.run --help
```

### Installation Flow

1. **Download** - User downloads the .run file
2. **Execute** - `./installer.run` (one command)
3. **Auto-Extract** - Files extracted to `./huddle-node-manager/`
4. **Auto-Install** - `install-hnm.sh` runs automatically
5. **Complete** - HNM ready to use, optional cleanup

## 🔧 Technical Details

### How It Works

The self-extracting installer is a **shell script + tar.gz archive** combined into one file:

```
┌─────────────────────────────────┐
│ Shell Script Header             │  ← Extraction logic
│ - Argument parsing              │
│ - Directory creation            │  
│ - Archive extraction            │
│ - Auto-installation             │
├─────────────────────────────────┤
│ __ARCHIVE_BELOW__               │  ← Marker
├─────────────────────────────────┤
│ Binary tar.gz Data              │  ← Complete HNM package
│ - install-hnm.sh                │
│ - hnm executable                │
│ - All supporting files          │
│ - API components                │
│ - Documentation                 │
└─────────────────────────────────┘
```

### Included Components

The installer automatically includes:

**Core Files** (Always included):
- `install-hnm.sh` - Main installer
- `hnm` - HNM executable  
- `setup-ipfs-node.sh` - IPFS setup
- `requirements.txt` - Python dependencies
- Documentation files

**Supporting Scripts** (If present):
- `ipfs-*-manager.sh` - IPFS management scripts
- `setup_dependencies.py` - Dependency installer
- `api_key_manager.sh` - API key management

**Optional Directories** (If present):
- `api/` - API components
- `models/` - ML models
- `scripts/` - Utility scripts  
- `docs/` - Documentation

## 🎯 Distribution Strategies

### GitHub Releases
```bash
# Create release with self-extracting installer
gh release create v2.0.0 \
  huddle-node-manager-v2.0.0-installer.run \
  --title "HNM v2.0.0" \
  --notes "Self-extracting installer for easy installation"
```

### Direct Download
Upload the `.run` file to your web server:
```
https://releases.example.com/hnm/huddle-node-manager-v2.0.0-installer.run
```

### User Instructions
```markdown
## 📥 Installation

### One-Click Install
```bash
# Download installer
curl -L https://releases.example.com/hnm/huddle-node-manager-v2.0.0-installer.run -o hnm-installer.run

# Run installer  
chmod +x hnm-installer.run
./hnm-installer.run
```

That's it! HNM is now installed and ready to use.
```

## 🧪 Testing

The build script automatically tests the installer:

```bash
# Full build and test
./build-release.sh

# Test existing installer
./build-release.sh --test-only
```

**Tests performed**:
- ✅ Extraction functionality
- ✅ File permissions  
- ✅ Help system
- ✅ Directory structure

## 🔍 Troubleshooting

### Common Issues

**"Permission denied"**
```bash
chmod +x installer.run
```

**"No space left on device"**
- Installer extracts to current directory
- Ensure sufficient disk space (~200MB)

**"Archive damaged"**
- Re-download the installer
- Check file integrity

### Debug Mode

```bash
# Extract files without installing
./installer.run --extract-only

# Check extracted files
cd huddle-node-manager
ls -la
./install-hnm.sh --help
```

## 📋 Customization

### Custom Version
Edit `create-self-extracting-installer.sh`:
```bash
HNM_VERSION="2.1.0"  # Change version number
```

### Custom Files
Modify the file copying section to include/exclude specific components:
```bash
# Add custom files
cp my-custom-script.sh "$PACKAGE_DIR/"

# Skip optional directories
# for dir in api models scripts docs; do
```

### Custom Installer Behavior
Edit the installer template to:
- Add custom prompts
- Change default directories  
- Add pre/post-install hooks
- Customize user messages

## 🎉 Result

**Before**: Users need to clone repo, understand directory structure, run multiple commands

**After**: Users download one file, run one command, HNM is installed!

```bash
# Old way:
git clone https://github.com/org/huddle-node-manager.git
cd huddle-node-manager  
chmod +x install-hnm.sh
./install-hnm.sh

# New way:
./huddle-node-manager-v2.0.0-installer.run
```

**Professional, Simple, Reliable! 🚀** 