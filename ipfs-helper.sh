#!/bin/bash

function show_help {
  echo "HuddleAI IPFS Helper Tool"
  echo "----------------------"
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  add [file/folder]   - Add content to IPFS and pin it"
  echo "  pins               - List all pinned content"
  echo "  unpin [hash]       - Unpin content by hash"
  echo "  status             - Check IPFS node status"
  echo "  help               - Show this help message"
}

case "$1" in
  add)
    if [ -z "$2" ]; then
      echo "Error: Please specify a file or folder to add"
      exit 1
    fi
    echo "Adding to IPFS: $2"
    HASH=$(ipfs add -r -Q "$2")
    echo "Added with hash: $HASH"
    echo "Your content is available at:"
    echo "  - http://localhost:8080/ipfs/$HASH"
    echo "  - https://ipfs.io/ipfs/$HASH"
    ;;
  pins)
    echo "Pinned content:"
    ipfs pin ls --type=recursive
    ;;
  unpin)
    if [ -z "$2" ]; then
      echo "Error: Please specify a hash to unpin"
      exit 1
    fi
    ipfs pin rm "$2"
    echo "Unpinned: $2"
    ;;
  status)
    echo "IPFS Node Status:"
    echo "-----------------"
    
    # Check if daemon is running
    if ipfs swarm peers &>/dev/null; then
      echo "✅ IPFS daemon is running"
      echo "Connected to $(ipfs swarm peers | wc -l | tr -d ' ') peers"
      
      # Get repo stats
      REPO_SIZE=$(ipfs repo stat --human | grep "RepoSize" | awk '{print $2}')
      echo "Repository size: $REPO_SIZE"
      
      # Get node ID
      NODE_ID=$(ipfs id -f="<id>")
      echo "Node ID: $NODE_ID"
      
      # Get gateway and API addresses
      GATEWAY=$(ipfs config Addresses.Gateway)
      API=$(ipfs config Addresses.API)
      echo "Gateway address: $GATEWAY"
      echo "API address: $API"
    else
      echo "❌ IPFS daemon is not running"
    fi
    ;;
  *)
    show_help
    ;;
esac
