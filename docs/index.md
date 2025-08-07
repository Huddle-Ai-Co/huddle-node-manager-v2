# IPFS Node Manager Documentation

Welcome to the IPFS Node Manager documentation. This documentation covers the various components and functionalities of the IPFS Node Manager.

## Components

The IPFS Node Manager consists of several modular components:

- **[Daemon Management](daemon-management.md)**: Start, stop, restart, and monitor the IPFS daemon
- **[Content Management](content-management.md)**: Add, list, remove, search, and publish content
- **[WebUI Management](webui-management.md)**: Access, configure, and fix the IPFS WebUI
- **[Community Management](community.md)**: Connect with peers and participate in the IPFS network
- **[Semantic Search](search.md)**: Find content intelligently using vector embeddings (requires HuddleAI API subscription)
- **[Troubleshooting](troubleshooting.md)**: Diagnose and fix common IPFS issues

## Quick Start

### Installation

1. Clone this repository
2. Make the scripts executable: `chmod +x *.sh`
3. Run the modern command: `hnm help`

### Basic Commands

```bash
# Start the IPFS daemon
hnm start

# Add content to IPFS
hnm content add myfile.txt

# Open the WebUI
hnm webui

# Check node status
hnm status

# Connect with peers
hnm community peers

# Search content semantically
hnm search query "your search query"

# Fix common issues
hnm troubleshoot fix
```

## Command Reference

### Main Helper Script

```bash
hnm [command] [options]
```

### Available Commands

- **add [file/folder]**: Add content to IPFS and pin it
- **pins**: List all pinned content
- **unpin [hash]**: Unpin content by hash
- **status**: Check IPFS node status
- **webui [command]**: Manage IPFS WebUI (open|config|fix|import)
- **daemon [command]**: Manage the IPFS daemon (start|stop|restart|status|logs|clean)
- **content [command]**: Advanced content management (add|list|remove|search|info|publish|backup|restore)
- **community [cmd]**: Manage community interactions (peers|connect|publish|subscribe|topics)
- **search [command]**: Semantic search across IPFS content (index|query|list|remove|build)
- **troubleshoot [cmd]**: Diagnose and fix IPFS issues (daemon|api|mfs|repo|content|import|fix)
- **help**: Show help message

## Requirements

- IPFS (Kubo) installed and in your PATH
- Bash shell
- Standard Unix utilities (grep, awk, etc.)
- HuddleAI API subscription key (for semantic search functionality, sign up at https://huddleai-apim.developer.azure-api.net)
- jq command-line JSON processor (for semantic search functionality)

## About

The IPFS Node Manager is designed to make it easy to manage IPFS nodes, content, interact with the IPFS network, search content semantically, and troubleshoot common issues. It provides a modular approach to IPFS node management through a collection of specialized scripts. 