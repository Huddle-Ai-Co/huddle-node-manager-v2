#!/bin/bash

# Open IPFS WebUI - A helper script to open the IPFS WebUI in the browser
# This script automatically parses the API address from IPFS config

# Function to display banner
display_banner() {
cat << "EOF"
 _   _  _   _  ____  ____  _      _____ 
| | | || | | ||  _ \|  _ \| |    | ____|
| |_| || | | || | | | | | | |    |  _|  
|  _  || |_| || |_| | |_| | |___ | |___ 
|_| |_| \___/ |____/|____/|_____||_____|

=====================================================
      IPFS WebUI | Manage Your Decentralized Storage
=====================================================
EOF
echo ""
}

# Check if IPFS daemon is running
check_ipfs_daemon() {
    if ! ipfs swarm peers &>/dev/null; then
        echo "❌ IPFS daemon is not running. Please start it first."
        echo ""
        echo "To start the daemon, run:"
        echo "ipfs daemon"
        echo ""
        echo "If you get a lock file error, you can fix it with:"
        echo "rm -f ~/.ipfs/repo.lock"
        echo "ipfs daemon"
        return 1
    fi
    return 0
}

# Handle lock file if it exists but daemon is not running
handle_lock_file() {
    if [ -f ~/.ipfs/repo.lock ]; then
        # Check if there's actually an IPFS process running
        if ! pgrep -x "ipfs" > /dev/null; then
            echo "⚠️ Found stale lock file but no IPFS process is running."
            echo "Would you like to remove the lock file? (y/N)"
            read -r remove_lock
            
            if [[ "$remove_lock" =~ ^[Yy]$ ]]; then
                echo "Removing stale lock file..."
                rm -f ~/.ipfs/repo.lock
                echo "Lock file removed. You can now start the IPFS daemon."
                return 0
            else
                echo "Lock file not removed. Cannot proceed."
                return 1
            fi
        fi
    fi
    return 0
}

# Get API address from IPFS config
get_api_address() {
    # Get the API address from IPFS config
    API_ADDRESS=$(ipfs config Addresses.API)
    
    # Check if we got a valid address
    if [ -z "$API_ADDRESS" ]; then
        echo "❌ Failed to get API address from IPFS config."
        return 1
    fi
    
    echo "✅ Found API address: $API_ADDRESS"
    return 0
}

# Parse API address to get host and port
parse_api_address() {
    # Extract host and port from API address
    # Format is typically: /ip4/127.0.0.1/tcp/5001
    
    # Extract the IP address
    HOST=$(echo "$API_ADDRESS" | grep -o '/ip[46]/[^/]*' | head -1 | cut -d'/' -f3)
    
    # Extract the port
    PORT=$(echo "$API_ADDRESS" | grep -o '/tcp/[0-9]*' | head -1 | cut -d'/' -f3)
    
    if [ -z "$HOST" ] || [ -z "$PORT" ]; then
        echo "❌ Failed to parse host or port from API address."
        return 1
    fi
    
    echo "✅ Parsed host: $HOST, port: $PORT"
    return 0
}

# Open WebUI in browser
open_webui() {
    # Construct the WebUI URL
    WEBUI_URL="http://$HOST:$PORT/webui"
    
    echo "🌐 Opening WebUI at $WEBUI_URL"
    
    # Detect OS and use appropriate open command
    case "$(uname -s)" in
        Darwin*)    # macOS
            open "$WEBUI_URL"
            ;;
        Linux*)     # Linux
            if command -v xdg-open &> /dev/null; then
                xdg-open "$WEBUI_URL"
            elif command -v gnome-open &> /dev/null; then
                gnome-open "$WEBUI_URL"
            else
                echo "❌ Could not detect browser. Please open this URL manually:"
                echo "$WEBUI_URL"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)  # Windows
            start "$WEBUI_URL"
            ;;
        *)
            echo "❌ Unsupported operating system. Please open this URL manually:"
            echo "$WEBUI_URL"
            ;;
    esac
}

# Try alternative WebUI URLs if the main one fails
try_alternative_webui() {
    echo "ℹ️ If the WebUI doesn't open, try these alternative URLs:"
    echo "- http://$HOST:$PORT/webui"
    echo "- http://$HOST:$PORT/ipfs/bafybeiflkjt6bqwunqusgrdicnbnf55kyppdqdguwqdy3cksr4r6fhbzfi/"
    echo "- https://webui.ipfs.io/#/welcome?api=$HOST:$PORT"
    
    # Also try to update the WebUI
    echo ""
    echo "ℹ️ You can also try updating the WebUI with:"
    echo "ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '[\"http://localhost:3000\", \"http://$HOST:$PORT\", \"https://webui.ipfs.io\"]'"
    echo "ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '[\"PUT\", \"POST\", \"GET\"]'"
}

# Main function
main() {
    display_banner
    
    # Check if IPFS daemon is running
    check_ipfs_daemon || { handle_lock_file && exit 1; }
    
    # Get API address
    get_api_address || exit 1
    
    # Parse API address
    parse_api_address || exit 1
    
    # Open WebUI
    open_webui
    
    # Provide alternative URLs
    try_alternative_webui
}

# Run the main function
main 