# IPFS WebUI Management

This document covers the WebUI management functionality of the IPFS Node Manager.

## Overview

The IPFS Node Manager includes comprehensive WebUI management capabilities that allow you to access, configure, and fix the IPFS WebUI. The system is designed to make it easy to visualize and interact with your IPFS node through a web interface.

## WebUI Commands

The WebUI management functionality is accessible through the main helper script:

```bash
hnm webui [command] [options]
```

### Available Commands

- **open**: Open the IPFS WebUI in your browser (default when no command is specified)
- **import**: Import pinned content to MFS so it appears in WebUI
- **config**: Configure WebUI settings (CORS, etc.)
- **fix**: Fix common WebUI issues

### Examples

```bash
# Open the WebUI in your browser
./ipfs-helper.sh webui

# Import pinned content to MFS for WebUI visibility
./ipfs-helper.sh webui import

# Configure WebUI settings
./ipfs-helper.sh webui config

# Fix common WebUI issues
./ipfs-helper.sh webui fix
```

## Opening the WebUI

The WebUI provides a graphical interface to your IPFS node, allowing you to:

- Browse files in your MFS
- Explore the IPFS network
- View peers and connection status
- Monitor bandwidth and resource usage
- Configure your node settings

To open the WebUI:

```bash
./ipfs-helper.sh webui
```

This command will:
1. Check if the IPFS daemon is running
2. Get the API address from your IPFS configuration
3. Construct the WebUI URL
4. Open the URL in your default browser

If the WebUI doesn't open automatically, the command will provide alternative URLs you can use.

## Importing Content to WebUI

By default, content added to IPFS is not automatically visible in the WebUI's Files section. To make your content visible, you need to import it to the Mutable File System (MFS).

The `webui import` command imports all your pinned content to MFS under the `/pins` directory:

```bash
./ipfs-helper.sh webui import
```

This command will:
1. Get a list of all pinned content
2. Create a `/pins` directory in MFS if it doesn't exist
3. Import each pinned item to MFS
4. Report on the success or failure of each import

Note: When using the `content add` command, content is automatically imported to MFS unless you use the `--no-import` flag.

## Configuring the WebUI

The WebUI requires certain CORS (Cross-Origin Resource Sharing) settings to function properly. The `webui config` command configures these settings:

```bash
./ipfs-helper.sh webui config
```

This command will:
1. Set the appropriate CORS headers for the WebUI
2. Provide instructions for restarting the daemon to apply the changes

## Fixing WebUI Issues

If you're experiencing issues with the WebUI, the `webui fix` command can help:

```bash
./ipfs-helper.sh webui fix
```

This command will:
1. Set the appropriate CORS headers
2. Update to the latest WebUI version if available
3. Restart the IPFS daemon to apply the changes

## Technical Details

The WebUI management functionality is implemented in the `ipfs-helper.sh` script. It uses IPFS commands to configure the node and manage the WebUI.

The WebUI itself is a web application that connects to your local IPFS node through its API. The WebUI is served from your local node, ensuring that you have full control over your data. 