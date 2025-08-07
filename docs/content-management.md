# IPFS Content Management

This document covers the content management functionality of the IPFS Node Manager.

## Overview

The IPFS Node Manager includes a comprehensive content management system that allows you to add, list, search, and remove content from your IPFS node. The system is designed to be user-friendly and integrates with the WebUI for easy visual management.

## Content Management Commands

The content management functionality is accessible through the main helper script:

```bash
hnm content [command] [options]
```

### Available Commands

- **add [file/folder]**: Add content to IPFS with detailed information
- **list**: List all pinned content with details
- **remove [hash]**: Remove (unpin) content
- **search [query]**: Search for content in your pins
- **info [hash]**: Show detailed info about content
- **publish [hash] [name]**: Publish content to IPNS
- **backup**: Backup all pinned content metadata
- **restore [file]**: Restore pins from backup

### Examples

```bash
# Add content to IPFS with automatic import to MFS
hnm content add myfile.txt

# Add content without importing to MFS
hnm content add --no-import myfile.txt

# List all pinned content
hnm content list

# Search for content containing "document"
hnm content search "document"

# Get detailed info about content
hnm content info QmHash...

# Remove content
hnm content remove QmHash...

# Publish content to IPNS
hnm content publish QmHash... myname

# Backup all pinned content metadata
hnm content backup

# Restore pins from backup
hnm content restore backup-20231015.json
```

## WebUI Integration

The content management system is integrated with the IPFS WebUI, allowing you to see your content in the WebUI's Files section. When you add content using the `content add` command, it is automatically imported to the Mutable File System (MFS) under the `/pins` directory, making it visible in the WebUI.

### Automatic Import

By default, all content added with the `content add` command is automatically imported to MFS for WebUI visibility. The system verifies that the content was properly imported and runs troubleshooting if verification fails.

You can skip the automatic import using the `--no-import` flag:

```bash
hnm content add --no-import myfile.txt
```

### Manual Import

If you have existing pinned content that is not visible in the WebUI, you can import it manually:

```bash
hnm webui import
```

This command will import all pinned content to MFS, making it visible in the WebUI.

## Content Details

When adding or viewing content, the system provides detailed information:

- **Hash**: The IPFS content identifier (CID)
- **Type**: Whether it's a file or directory
- **Size**: The size of the content
- **URLs**: Links to access the content via local and public gateways

## Technical Details

The content management system is implemented in the `ipfs-content-manager.sh` script, which provides a modular approach to managing content on IPFS. This script can be used standalone or through the main helper script.

The system uses IPFS commands to add, pin, list, and remove content. It also provides additional functionality like searching, publishing to IPNS, and backing up/restoring pins. 