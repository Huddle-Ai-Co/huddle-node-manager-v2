# HNM (Huddle Node Manager) Backwards Compatibility Guide

## Overview

This document outlines the backwards compatibility strategy for migrating from the original **Huddle IPFS Node Manager** to the new **HNM (Huddle Node Manager)** branding and command structure.

## 🔄 Command Migration

### Old vs New Commands

| **Old Command** | **New Command** | **Status** | **Action Required** |
|-----------------|-----------------|------------|---------------------|
| `ipfs-manager-version` | `hnm --version` | ⚠️ **Missing** | Create new command |
| `ipfs-manager-uninstall` | `hnm uninstall` | ⚠️ **Missing** | Create new command |
| `ipfs-setup` | `hnm setup` | ⚠️ **Missing** | Create new command |
| `ipfs-manager` | `hnm` | ⚠️ **Missing** | Create main command |
| N/A | `hnm update` | ⚠️ **Missing** | Create new command |

### Backwards Compatibility Strategy

1. **Maintain Old Commands**: Keep existing commands working during transition period
2. **Create New Commands**: Implement new HNM command structure
3. **Deprecation Warnings**: Show migration notices when old commands are used
4. **Automatic Migration**: Offer to migrate user configurations and data

## 📋 Required Updates

### 1. Update Installation Script (`install.sh`)

The current installation script needs updates to:

- **Version Detection**: Check for existing installations and handle upgrades
- **Command Migration**: Create new HNM commands alongside old ones
- **Configuration Migration**: Move old config files to new structure
- **Branding Updates**: Update all text references to Huddle Node Manager

### 2. Create HNM Main Command

Create a new `hnm` command that handles:

```bash
hnm --version             # Show version information
hnm --help                # Show help and available commands
hnm setup                 # Setup IPFS node (replaces ipfs-setup)
hnm update                # Check for and install updates
hnm uninstall             # Uninstall HNM
hnm status                # Show node status
hnm config                # Configuration management
hnm start                 # Start IPFS daemon and services
hnm stop                  # Stop IPFS daemon and services
hnm logs                  # View system logs
```

### 3. Version Management Updates

Current version management needs:

- **IPNS Integration**: Use IPNS for version checking instead of GitHub
- **Automatic Updates**: Implement seamless update mechanism
- **Rollback Support**: Allow rolling back to previous versions
- **Migration Tracking**: Track which version user migrated from

### 4. Configuration Migration

Handle migration of:

- **Config Files**: `$HOME/huddle-ipfs/config.json` → `$HOME/.hnm/config.json`
- **Data Directory**: `$HOME/huddle-ipfs/` → `$HOME/.hnm/`
- **Symlinks**: Update all symlinks to point to new commands
- **Environment Variables**: Update any environment variable references

## 🛠️ Implementation Plan

### Phase 1: Backwards Compatibility (Immediate)

1. **Update `install.sh`** with version detection and migration logic
2. **Create wrapper scripts** for new commands that call old functionality
3. **Add deprecation warnings** to old commands
4. **Update documentation** with migration instructions

### Phase 2: New Command Structure (Next Release)

1. **Implement new `hnm` main command**
2. **Create subcommand structure**
3. **Add configuration migration logic**
4. **Update IPNS version checking**

### Phase 3: Full Migration (Future Release)

1. **Remove old commands** (with grace period)
2. **Complete configuration migration**
3. **Update all documentation**
4. **Announce deprecation timeline**

## 🔧 Technical Implementation

### Installation Script Updates

```bash
# Version detection and migration logic
VERSION="2.0.0"  # New HNM version
LEGACY_VERSION_FILE="$HOME/huddle-ipfs/version.txt"
NEW_VERSION_FILE="$HOME/.hnm/version.txt"

# Check for legacy installation
if [ -f "$LEGACY_VERSION_FILE" ]; then
    LEGACY_VERSION=$(cat "$LEGACY_VERSION_FILE")
    echo "🔄 Migrating from Huddle IPFS Node Manager v$LEGACY_VERSION to HNM v$VERSION"
    
    # Perform migration
    migrate_legacy_installation
fi
```

### Command Wrapper Example

```bash
#!/bin/bash
# hnm - Main Huddle Node Manager command

HNM_VERSION="2.0.0"
HNM_HOME="$HOME/.hnm"

show_help() {
    cat << EOF
HNM (Huddle Node Manager) v$HNM_VERSION
Decentralized IPFS Node Management

Usage: hnm [COMMAND]

Commands:
  setup        Setup IPFS node and configure HNM
  start        Start IPFS daemon and HNM services
  stop         Stop IPFS daemon and HNM services
  status       Show current node and service status
  update       Check for and install updates
  config       Manage HNM configuration
  logs         View system logs
  uninstall    Remove HNM from system
  --version    Show version information
  --help       Show this help message

Examples:
  hnm setup           # Initial setup
  hnm start           # Start services
  hnm status          # Check status
  hnm update          # Update to latest version

For more information, visit: https://github.com/your-org/huddle-node-manager
EOF
}

case "$1" in
    --version|-v)
        echo "HNM (Huddle Node Manager) v$(cat $HNM_HOME/version.txt 2>/dev/null || echo $HNM_VERSION)"
        ;;
    setup)
        echo "🚀 Setting up Huddle Node Manager..."
        $HNM_HOME/scripts/setup-ipfs-node.sh
        ;;
    start)
        echo "▶️  Starting HNM services..."
        $HNM_HOME/scripts/start-services.sh
        ;;
    stop)
        echo "⏹️  Stopping HNM services..."
        $HNM_HOME/scripts/stop-services.sh
        ;;
    status)
        echo "📊 HNM Status:"
        $HNM_HOME/scripts/status-check.sh
        ;;
    update)
        echo "🔄 Checking for updates..."
        $HNM_HOME/scripts/check-updates.sh
        ;;
    config)
        echo "⚙️  HNM Configuration:"
        $HNM_HOME/scripts/config-manager.sh "$@"
        ;;
    logs)
        echo "📋 HNM Logs:"
        $HNM_HOME/scripts/view-logs.sh
        ;;
    uninstall)
        echo "🗑️  Uninstalling HNM..."
        $HNM_HOME/scripts/uninstall.sh
        ;;
    --help|-h|help|"")
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Run 'hnm --help' for available commands."
        exit 1
        ;;
esac
```

## 📊 Migration Status Tracking

### Current Status: ⚠️ **Action Required**

- [ ] **Install Script**: Needs version detection and migration logic
- [ ] **Command Structure**: New `hnm` command needs to be created
- [ ] **Version Management**: IPNS-based update checking not implemented
- [ ] **Configuration Migration**: Automatic migration not available
- [ ] **Documentation**: Commands referenced in SHAREABLE_LINK.md don't exist

### Immediate Actions Needed

1. **Create `hnm` main command** with subcommand structure
2. **Update `install.sh`** to handle version detection and migration
3. **Implement version checking** using IPNS
4. **Create migration scripts** for configuration and data
5. **Update all documentation** to reflect new command structure

## 🚨 Breaking Changes

### Commands That Will Change

- `ipfs-manager-version` → `hnm --version`
- `ipfs-manager-uninstall` → `hnm uninstall`
- `ipfs-setup` → `hnm setup`
- `ipfs-manager` → `hnm`

### File Locations That Will Change

- `$HOME/huddle-ipfs/` → `$HOME/.hnm/`
- `/usr/local/bin/ipfs-*` → `/usr/local/bin/hnm`

### Configuration Changes

- Config file format may change to support new features
- Environment variables may be renamed for consistency
- API endpoints may change to reflect new branding

## 🔗 Related Files to Update

1. **`install.sh`** - Main installation script
2. **`setup-ipfs-node.sh`** - Node setup script
3. **`SHAREABLE_LINK.md`** - Update command references
4. **`README.md`** - Update branding and commands
5. **`compatibility-check.sh`** - Update branding
6. **`PRODUCTION_READY.md`** - Update command references
7. **`IPFS_DISTRIBUTION.md`** - Update distribution info

## 📅 Timeline

- **Immediate**: Create `hnm` command and fix documentation
- **Week 1**: Implement basic `hnm` command structure
- **Week 2**: Add version management and update functionality
- **Week 3**: Implement configuration migration
- **Week 4**: Complete documentation updates
- **Month 2**: Begin deprecation of old commands
- **Month 6**: Remove old commands (with user notification)

## 🎯 Brand Identity

### New Branding
- **Full Name**: **Huddle Node Manager**
- **Short Name**: **HNM**
- **Command**: `hnm`
- **Tagline**: "Decentralized IPFS Node Management"
- **Logo**: Glassmorphism shield design

### Professional Benefits
- **Concise**: 3-character command is easy to type
- **Memorable**: HNM is intuitive and professional
- **Consistent**: Maintains Huddle brand identity
- **Scalable**: Works well for enterprise adoption

---

**Note**: This migration maintains full backwards compatibility while introducing the new **HNM (Huddle Node Manager)** branding and improved command structure. Users will be guided through the migration process with clear instructions and automatic migration tools. 