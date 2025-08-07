# IPFS Troubleshooting

This document covers the troubleshooting functionality added to the IPFS Node Manager.

## Overview

The IPFS Node Manager includes a comprehensive troubleshooting system that can diagnose and fix common IPFS issues. This system is integrated with the content management functionality to provide automatic verification and self-healing capabilities.

## Troubleshooting Commands

The troubleshooting functionality is accessible through the main helper script:

```bash
hnm troubleshoot [command] [options]
```

### Available Commands

- **daemon**: Check if the IPFS daemon is running
- **api**: Check if the IPFS API is accessible
- **mfs**: Check and repair MFS health
- **repo**: Check repository health
- **content [hash]**: Troubleshoot specific content by hash
- **import [hash]**: Attempt to import content to MFS
- **flags**: Help with command-line flag issues
- **fix**: Apply fixes for common issues

### Examples

```bash
# Check if daemon is running
hnm troubleshoot daemon

# Check API accessibility
hnm troubleshoot api

# Check and repair MFS
hnm troubleshoot mfs

# Check repository health
hnm troubleshoot repo

# Troubleshoot specific content
hnm troubleshoot content QmHash...

# Force import content to MFS
hnm troubleshoot import QmHash...

# Get help with command flags
hnm troubleshoot flags

# Fix common issues
hnm troubleshoot fix
```

## Automatic Content Verification

When adding content with `content add`, the system now:

1. Adds and pins the content to IPFS
2. Automatically imports it to MFS for WebUI visibility
3. Verifies the content appears in MFS
4. If verification fails, automatically runs diagnostics and repair

This ensures that content is properly added and visible in the WebUI without requiring manual intervention.

## Enhanced Import Functionality

The troubleshooting system now includes multiple methods for importing content to MFS when the standard method fails:

1. **Direct Copy**: The standard method using `ipfs files cp`
2. **Write Method**: Using `ipfs files write` for files
3. **Read/Write via Temp File**: Reading content and writing through a temporary file
4. **Directory Copy**: For directories, creating the directory and copying contents individually
5. **MFS Corruption Check**: Checking for and fixing MFS corruption issues

Each method is tried in sequence until one succeeds or all methods are exhausted.

## Command-Line Flag Help

The new `flags` command provides help with common command-line flag issues:

```bash
hnm troubleshoot flags
```

This command explains:
- How to properly use the `--no-import` flag
- The importance of flag order in commands
- How to handle multiple files

## Self-Healing Capabilities

The troubleshooting system can automatically:

- **Check daemon and API status**: Ensures the IPFS node is running and accessible
- **Verify content exists and is pinned**: Confirms content was properly added to IPFS
- **Repair MFS issues**: Fixes common Mutable File System problems
- **Try multiple import methods**: Uses different approaches for problematic content
- **Check for repository issues**: Identifies and suggests fixes for repo problems
- **Handle stale lock files**: Detects and suggests fixes for lock file issues

## Common Issues and Solutions

### Content Not Visible in WebUI

If content is not visible in the WebUI after adding:

```bash
# Import all pinned content to MFS
hnm webui import

# Or troubleshoot specific content
hnm troubleshoot content QmHash...

# Or force import specific content
hnm troubleshoot import QmHash...
```

### Flag Order Issues

If you're experiencing issues with command flags:

```bash
# Get help with command flags
hnm troubleshoot flags
```

### IPFS Daemon Not Starting

If the IPFS daemon fails to start:

```bash
# Check for stale lock files
hnm daemon clean

# Check repository health
hnm troubleshoot repo
```

### MFS Issues

If you're experiencing issues with the Mutable File System:

```bash
# Check and repair MFS
hnm troubleshoot mfs
```

### Repository Issues

For repository-related problems:

```bash
# Check repository health
hnm troubleshoot repo

# Run garbage collection
ipfs repo gc
```

## Integration with Content Management

The troubleshooting system is integrated with the content management functionality. When adding content with `content add`, the system automatically verifies that the content was properly imported to MFS. If verification fails, it automatically runs the troubleshooter to diagnose and fix the issue.

You can skip the automatic import to MFS using the `--no-import` flag:

```bash
hnm content add --no-import myfile.txt
```

## Technical Details

The troubleshooting system is implemented in the `ipfs-troubleshoot-manager.sh` script, which provides a modular approach to diagnosing and fixing IPFS issues. This script can be used standalone or through the main helper script.

The system uses a variety of IPFS commands and utilities to check the status of the daemon, API, MFS, and repository. It also provides specialized functions for troubleshooting specific content and importing content to MFS. 