# Huddle Node Manager - Distribution Package

## 🚀 Quick Start

1. **Extract** the downloaded `huddle-node-manager-distribution.tar.gz` file
2. **Open Terminal** and navigate to the extracted directory
3. **Run the installer**: `./INSTALL.sh`

That's it! The installer will handle everything else.

## 📋 What's Included

This distribution package contains:

- **`INSTALL.sh`** - Main installer (run this first!)
- **`install-hnm-complete.sh`** - Complete installation script
- **`install-hnm.sh`** - Basic installation script
- **`hnm`** - Command-line interface
- **`scripts/`** - All Python scripts and utilities
- **`docker/`** - Docker testing infrastructure
- **`docs/`** - Documentation
- **`Data.zip`** - Medical data files
- **`docker.zip`** - Docker components
- **`bundled_models.zip`** - AI models

## 🔧 Manual Installation

If you prefer to install manually:

1. Run: `./scripts/initialize-hnm-distribution.sh`
2. Navigate to: `cd ~/.huddle-node-manager`
3. Run: `./install-hnm-complete.sh`

## 🧪 Testing

After installation, test the system:

```bash
# Test the installation
hnm test dynamic

# View available commands
hnm help

# Run Docker tests
hnm docker list
```

## 📁 Installation Locations

The installer will create:

- `~/.huddle-node-manager/` - Main application directory
- `~/.local/lib/huddle-node-manager/` - Scripts and utilities
- `~/.local/share/doc/huddle-node-manager/` - Documentation
- `~/.config/huddle-node-manager/` - Configuration files

## 🆘 Troubleshooting

If you encounter issues:

1. Check that you're running from the extracted directory
2. Ensure you have Python 3.7+ installed
3. Try running the manual installation steps above
4. Check the logs in `~/.huddle-node-manager/`

## 📞 Support

For support, check the documentation in `docs/` or run `hnm help` for available commands. 