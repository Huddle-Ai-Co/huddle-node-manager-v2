#!/bin/bash

# HNM (Huddle Node Manager) - IPFS Content Manager
# Advanced content management for the modern Huddle Node Manager
# This script provides user-friendly commands for adding, listing, and managing IPFS content

# Function to display banner
display_banner() {
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│                      HUDDLE NODE MANAGER                       │"
    echo "│                                                                 │"
    echo "│  🏠 Content Manager                                             │"
    echo "│  📁 Advanced IPFS Content Management                           │"
    echo "│  ⬆️  Upgraded from IPFS Content Manager                        │"
    echo "│  🔧 Part of Huddle Node Manager Suite                          │"
    echo "└─────────────────────────────────────────────────────────────────┘"
}

# Function to get appropriate command prefix based on calling context
get_command_prefix() {
    # Always return the modern command format for consistency
    echo "hnm content"
}

# Function to show help message
show_help() {
    display_banner
    echo ""
    echo "🏠 HNM (Huddle Node Manager) - Content Manager"
    echo "==============================================="
    echo "📁 Advanced IPFS content management with enhanced UX"
    echo ""
    
    # Use context-aware command prefix
    local CMD_PREFIX=$(get_command_prefix)
    echo "Usage: $CMD_PREFIX [command] [options]"
    echo ""
    echo "🎯 Commands:"
    echo "  add [file/folder]      - Add content to IPFS, pin it, and import to MFS for WebUI visibility"
    echo "  list                   - List all pinned content"
    echo "  remove [hash]          - Remove (unpin) content by hash"
    echo "  search [term]          - Search for content in your pins"
    echo "  info [hash]            - Show detailed info about content"
    echo "  publish [hash] [name]  - Publish content to IPNS"
    echo "  backup [directory]     - Backup all pinned content metadata"
    echo "  restore [file]         - Restore pins from backup"
    echo "  help                   - Show this help message"
    echo ""
    echo "⚙️  Options:"
    echo "  --quiet, -q            - Minimal output"
    echo "  --verbose, -v          - Verbose output"
    echo "  --json                 - Output in JSON format"
    echo "  --no-import            - Skip importing to MFS (won't show in WebUI)"
    echo ""
    echo "💡 Examples:"
    echo "  $CMD_PREFIX add ~/Documents/important.pdf"
    echo "  $CMD_PREFIX add --no-import ~/Documents/private.pdf"
    echo "  $CMD_PREFIX list"
    echo "  $CMD_PREFIX search document"
    echo ""
    echo "🚀 Command Format:"
    echo "   This tool is part of the Huddle Node Manager (HNM) suite"
    echo "   All operations can be performed using the '$CMD_PREFIX' prefix"
}

# Function to check if IPFS daemon is running
check_daemon_running() {
    if pgrep -x "ipfs" > /dev/null; then
        # Double check with ipfs command
        if ipfs swarm peers &>/dev/null; then
            return 0  # Daemon is running
        fi
    fi
    return 1  # Daemon is not running
}

# Function to ensure daemon is running before proceeding
ensure_daemon_running() {
    if ! check_daemon_running; then
        echo "❌ IPFS daemon is not running. Please start it first with:"
        echo "hnm start"
        return 1
    fi
    return 0
}

# Function to add content to IPFS
add_content() {
    # Parse arguments
    local NO_IMPORT=false
    local FILE_PATH=""
    
    # Process arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-import)
                NO_IMPORT=true
                shift
                ;;
            --quiet|-q)
                # Just skip these flags, they're handled later
                shift
                ;;
            --json)
                # Just skip this flag, it's handled later
                shift
                ;;
            --*)
                # Skip other flags
                shift
                ;;
            *)
                # Assume it's a file path if it exists
                if [ -e "$1" ]; then
                    FILE_PATH="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Check if we have a file/folder to add
    if [ -z "$FILE_PATH" ]; then
        echo "❌ Error: No file or folder specified"
        echo "Usage: $(get_command_prefix) add [--no-import] [file/folder]"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    # Get file/folder name for display
    FILENAME=$(basename "$FILE_PATH")
    
    echo "📦 Adding to IPFS: $FILENAME"
    
    # Add the content with progress
    if [[ "$*" == *"--quiet"* ]] || [[ "$*" == *"-q"* ]]; then
        # Quiet mode - just get the hash
        HASH=$(ipfs add -Q -r "$FILE_PATH")
    elif [[ "$*" == *"--json"* ]]; then
        # JSON output
        ipfs add -r --json "$FILE_PATH"
        return 0
    else
        # Normal mode with progress
        echo "Adding content, please wait..."
        ADD_OUTPUT=$(ipfs add -r "$FILE_PATH")
        HASH=$(echo "$ADD_OUTPUT" | tail -n 1 | awk '{print $2}')
    fi
    
    # Check if we got a hash
    if [ -z "$HASH" ]; then
        echo "❌ Failed to add content"
        return 1
    fi
    
    echo "✅ Content added successfully!"
    echo ""
    echo "📋 Content Details:"
    echo "  Hash: $HASH"
    echo "  Type: $(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null || echo 'Unknown')"
    echo "  Size: $(ipfs files stat --format='<size>' /ipfs/$HASH 2>/dev/null | numfmt --to=iec-i || echo 'Unknown')"
    
    echo ""
    echo "🌐 Your content is available at:"
    echo "  - Local gateway: http://localhost:8080/ipfs/$HASH"
    echo "  - Public gateway: https://ipfs.io/ipfs/$HASH"
    
    # Automatically import to MFS for WebUI visibility
    if [ "$NO_IMPORT" = false ]; then
        echo ""
        echo "🔄 Importing content to MFS for WebUI visibility..."
        
        # Create /pins directory if it doesn't exist
        if ! ipfs files stat /pins &>/dev/null; then
            ipfs files mkdir -p /pins
        fi
        
        # Try to determine if it's a file or directory
        TYPE=$(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null || echo "unknown")
        
        # Import the content to MFS
        if [ "$TYPE" = "directory" ]; then
            # For directories, copy the entire directory
            ipfs files cp /ipfs/$HASH /pins/$HASH
        else
            # For files, copy the file
            ipfs files cp /ipfs/$HASH /pins/$HASH
        fi
        
        # Verify that the content was successfully imported by checking if the hash appears in /pins
        PINS_CONTENT=$(ipfs files ls /pins)
        if echo "$PINS_CONTENT" | grep -q "$HASH"; then
            echo "✅ Content imported to MFS (verified)"
            echo "You can now see this content in WebUI under Files > /pins/$HASH"
        else
            echo "⚠️ Content may not have been imported correctly. Verification failed."
            echo "Running troubleshooter to diagnose and fix the issue..."
            
            # Use the troubleshooting manager to diagnose and fix the issue
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "$SCRIPT_DIR/ipfs-troubleshoot-manager.sh" ]; then
                "$SCRIPT_DIR/ipfs-troubleshoot-manager.sh" import "$HASH"
            else
                echo "❌ Troubleshoot manager not found. You can manually import later with:"
                echo "ipfs files cp /ipfs/$HASH /pins/$HASH"
            fi
        fi
    else
        echo ""
        echo "ℹ️ Content was not imported to MFS (--no-import flag used)"
        echo "To make it visible in WebUI later, run:"
        echo "ipfs files cp /ipfs/$HASH /pins/$HASH"
    fi
    
    echo ""
    echo "📝 Commands to use this content:"
    echo "  - Get info: $(get_command_prefix) info $HASH"
    echo "  - Remove: $(get_command_prefix) remove $HASH"
    echo "  - Publish to IPNS: $(get_command_prefix) publish $HASH [name]"
    
    return 0
}

# Function to list pinned content
list_content() {
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    echo "📋 Listing pinned content..."
    
    # Check for format options
    if [[ "$*" == *"--json"* ]]; then
        # JSON output
        ipfs pin ls --type=recursive --quiet | xargs -I {} ipfs ls --size {} | jq -R -s 'split("\n") | map(select(length > 0) | split(" ") | {hash: .[0], size: .[1], name: .[2]}) | {pins: .}'
        return 0
    elif [[ "$*" == *"--quiet"* ]] || [[ "$*" == *"-q"* ]]; then
        # Quiet mode - just list hashes
        ipfs pin ls --type=recursive --quiet
        return 0
    fi
    
    # Get the list of pins
    PINS=$(ipfs pin ls --type=recursive)
    PIN_COUNT=$(echo "$PINS" | grep -c "recursive")
    
    echo "Found $PIN_COUNT pinned items:"
    echo ""
    
    # Format and display the pins
    echo "$PINS" | while read -r line; do
        HASH=$(echo "$line" | awk '{print $1}')
        if [ ! -z "$HASH" ]; then
            # Get size and file info if possible
            SIZE=$(ipfs files stat --format='<size>' /ipfs/$HASH 2>/dev/null | numfmt --to=iec-i 2>/dev/null || echo "unknown size")
            TYPE=$(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null || echo "unknown type")
            
            echo "🔒 $HASH ($SIZE, $TYPE)"
        fi
    done
    
    echo ""
    echo "💡 Tip: Use '$(get_command_prefix) info [hash]' to get more details about a specific item"
    
    return 0
}

# Function to remove (unpin) content
remove_content() {
    # Check if we have a hash to remove
    if [ -z "$1" ]; then
        echo "❌ Error: No content hash specified"
        echo "Usage: $(get_command_prefix) remove [hash]"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    HASH="$1"
    
    echo "🗑️ Removing content: $HASH"
    
    # Check if content is actually pinned
    if ! ipfs pin ls --type=recursive | grep -q "$HASH"; then
        echo "⚠️ Warning: Content is not pinned or hash not found"
        echo "Do you want to continue anyway? (y/N)"
        read -r continue_anyway
        
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            return 1
        fi
    fi
    
    # Remove the content
    if ipfs pin rm "$HASH"; then
        echo "✅ Content unpinned successfully"
        echo "Note: The content may still be available on the network if pinned by others"
        
        # Run garbage collection if requested
        if [[ "$*" == *"--gc"* ]]; then
            echo "🧹 Running garbage collection..."
            ipfs repo gc > /dev/null
            echo "✅ Garbage collection complete"
        else
            echo "💡 Tip: Run 'ipfs repo gc' to free up space"
        fi
    else
        echo "❌ Failed to unpin content"
        return 1
    fi
    
    return 0
}

# Function to search for content
search_content() {
    # Check if we have a search term
    if [ -z "$1" ]; then
        echo "❌ Error: No search term specified"
        echo "Usage: $(get_command_prefix) search [term]"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    TERM="$1"
    
    echo "🔍 Searching for: $TERM"
    
    # Get list of pins
    PINS=$(ipfs pin ls --type=recursive)
    
    # Initialize a counter for matches
    MATCHES=0
    
    # Search through pins
    echo "$PINS" | while read -r line; do
        HASH=$(echo "$line" | awk '{print $1}')
        if [ ! -z "$HASH" ]; then
            # Try to get content name or details
            CONTENT=$(ipfs ls "$HASH" 2>/dev/null || echo "")
            
            # Check if the term appears in the content details
            if echo "$CONTENT" | grep -q -i "$TERM" || echo "$HASH" | grep -q -i "$TERM"; then
                echo "✅ Match found: $HASH"
                echo "$CONTENT" | grep -i "$TERM" || echo "  (Match in hash)"
                echo ""
                MATCHES=$((MATCHES + 1))
            fi
        fi
    done
    
    if [ $MATCHES -eq 0 ]; then
        echo "❌ No matches found for: $TERM"
    else
        echo "Found $MATCHES matches for: $TERM"
    fi
    
    return 0
}

# Function to show detailed info about content
show_content_info() {
    # Check if we have a hash
    if [ -z "$1" ]; then
        echo "❌ Error: No content hash specified"
        echo "Usage: $(get_command_prefix) info [hash]"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    HASH="$1"
    
    echo "ℹ️ Content Information for: $HASH"
    echo "----------------------------"
    
    # Check if content exists
    if ! ipfs block stat "$HASH" &>/dev/null; then
        echo "❌ Content not found in the network"
        return 1
    fi
    
    # Check if content is pinned
    if ipfs pin ls | grep -q "$HASH"; then
        echo "📌 Pin Status: Pinned"
    else
        echo "📌 Pin Status: Not pinned"
    fi
    
    # Get content size
    SIZE=$(ipfs files stat --format='<size>' /ipfs/$HASH 2>/dev/null)
    if [ ! -z "$SIZE" ]; then
        HUMAN_SIZE=$(echo "$SIZE" | numfmt --to=iec-i 2>/dev/null || echo "$SIZE bytes")
        echo "📏 Size: $HUMAN_SIZE ($SIZE bytes)"
    else
        echo "📏 Size: Unknown"
    fi
    
    # Get content type
    TYPE=$(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null)
    echo "🗂️ Type: ${TYPE:-Unknown}"
    
    # List content if it's a directory
    if [ "$TYPE" = "directory" ]; then
        echo ""
        echo "📁 Directory Contents:"
        ipfs ls "$HASH" | while read -r line; do
            ITEM_HASH=$(echo "$line" | awk '{print $1}')
            ITEM_SIZE=$(echo "$line" | awk '{print $2}')
            ITEM_NAME=$(echo "$line" | awk '{print $3}')
            
            HUMAN_ITEM_SIZE=$(echo "$ITEM_SIZE" | numfmt --to=iec-i 2>/dev/null || echo "$ITEM_SIZE")
            echo "  - $ITEM_NAME ($HUMAN_ITEM_SIZE)"
        done
    fi
    
    # Show links
    echo ""
    echo "🔗 Access Links:"
    echo "  - Local gateway: http://localhost:8080/ipfs/$HASH"
    echo "  - Public gateway: https://ipfs.io/ipfs/$HASH"
    echo "  - Dweb link: ipfs://$HASH"
    
    return 0
}

# Function to publish content to IPNS
publish_content() {
    # Check if we have a hash
    if [ -z "$1" ]; then
        echo "❌ Error: No content hash specified"
        echo "Usage: $(get_command_prefix) publish [hash] [name]"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    HASH="$1"
    KEY_NAME="${2:-default}"
    
    echo "🔖 Publishing content to IPNS..."
    echo "Content hash: $HASH"
    echo "Key name: $KEY_NAME"
    
    # Check if the key exists
    if ! ipfs key list | grep -q "$KEY_NAME" && [ "$KEY_NAME" != "default" ]; then
        echo "Key '$KEY_NAME' does not exist. Would you like to create it? (y/N)"
        read -r create_key
        
        if [[ "$create_key" =~ ^[Yy]$ ]]; then
            echo "Creating new key: $KEY_NAME"
            ipfs key gen --type=rsa --size=2048 "$KEY_NAME"
        else
            echo "Operation cancelled"
            return 1
        fi
    fi
    
    # Publish the content
    echo "Publishing content, this may take a moment..."
    
    if [ "$KEY_NAME" = "default" ]; then
        RESULT=$(ipfs name publish --allow-offline "$HASH")
    else
        RESULT=$(ipfs name publish --allow-offline --key="$KEY_NAME" "$HASH")
    fi
    
    # Check if publish was successful
    if [ $? -ne 0 ]; then
        echo "❌ Failed to publish content"
        return 1
    fi
    
    # Extract the IPNS name from the result
    IPNS_NAME=$(echo "$RESULT" | grep -o "Qm[a-zA-Z0-9]*" || echo "$RESULT" | grep -o "k51[a-zA-Z0-9]*")
    
    echo "✅ Content published successfully!"
    echo ""
    echo "📋 IPNS Details:"
    echo "  IPNS Name: $IPNS_NAME"
    
    echo ""
    echo "🌐 Your content is now available at:"
    echo "  - Local gateway: http://localhost:8080/ipns/$IPNS_NAME"
    echo "  - Public gateway: https://ipfs.io/ipns/$IPNS_NAME"
    echo "  - IPNS link: ipns://$IPNS_NAME"
    
    echo ""
    echo "💡 Tip: To make this easier to remember, consider setting up DNSLink"
    echo "  Add this TXT record to your domain's DNS:"
    echo "  _dnslink.yourdomain.com. IN TXT \"dnslink=/ipns/$IPNS_NAME\""
    
    return 0
}

# Function to backup pinned content metadata
backup_content() {
    # Set default backup directory to current directory if not specified
    BACKUP_DIR="${1:-.}"
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    # Create backup filename with timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/ipfs_pins_backup_$TIMESTAMP.json"
    
    echo "💾 Backing up pinned content metadata..."
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Get list of pins and save as JSON
    echo "Collecting pin information..."
    
    # Create a JSON structure with pin information
    echo "{" > "$BACKUP_FILE"
    echo "  \"created\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$BACKUP_FILE"
    echo "  \"pins\": [" >> "$BACKUP_FILE"
    
    # Get all pins
    PINS=$(ipfs pin ls --type=recursive --quiet)
    TOTAL_PINS=$(echo "$PINS" | wc -l)
    CURRENT=0
    
    # Process each pin
    echo "$PINS" | while read -r HASH; do
        if [ ! -z "$HASH" ]; then
            CURRENT=$((CURRENT + 1))
            
            # Get content details
            SIZE=$(ipfs files stat --format='<size>' /ipfs/$HASH 2>/dev/null || echo "unknown")
            TYPE=$(ipfs files stat --format='<type>' /ipfs/$HASH 2>/dev/null || echo "unknown")
            
            # Add pin to JSON
            echo "    {" >> "$BACKUP_FILE"
            echo "      \"hash\": \"$HASH\"," >> "$BACKUP_FILE"
            echo "      \"size\": \"$SIZE\"," >> "$BACKUP_FILE"
            echo "      \"type\": \"$TYPE\"," >> "$BACKUP_FILE"
            echo "      \"backed_up\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" >> "$BACKUP_FILE"
            
            # Add comma if not the last item
            if [ $CURRENT -lt $TOTAL_PINS ]; then
                echo "    }," >> "$BACKUP_FILE"
            else
                echo "    }" >> "$BACKUP_FILE"
            fi
            
            # Show progress
            echo -ne "Progress: $CURRENT/$TOTAL_PINS pins processed\r"
        fi
    done
    
    # Close the JSON structure
    echo "" >> "$BACKUP_FILE"
    echo "  ]" >> "$BACKUP_FILE"
    echo "}" >> "$BACKUP_FILE"
    
    echo ""
    echo "✅ Backup completed successfully!"
    echo "Backup saved to: $BACKUP_FILE"
    
    return 0
}

# Function to restore pins from backup
restore_content() {
    # Check if we have a backup file
    if [ -z "$1" ]; then
        echo "❌ Error: No backup file specified"
        echo "Usage: $(get_command_prefix) restore [file]"
        return 1
    fi
    
    BACKUP_FILE="$1"
    
    # Check if the backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "❌ Error: Backup file does not exist: $BACKUP_FILE"
        return 1
    fi
    
    # Ensure daemon is running
    ensure_daemon_running || return 1
    
    echo "🔄 Restoring pins from backup..."
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: jq is required for parsing JSON but is not installed"
        echo "Please install jq and try again"
        return 1
    fi
    
    # Get the pins from the backup file
    PINS=$(jq -r '.pins[].hash' "$BACKUP_FILE")
    TOTAL_PINS=$(echo "$PINS" | wc -l)
    CURRENT=0
    SUCCESS=0
    FAILED=0
    
    echo "Found $TOTAL_PINS pins in backup"
    
    # Process each pin
    echo "$PINS" | while read -r HASH; do
        if [ ! -z "$HASH" ]; then
            CURRENT=$((CURRENT + 1))
            
            echo -ne "Restoring pin $CURRENT/$TOTAL_PINS: $HASH\r"
            
            # Try to pin the content
            if ipfs pin add "$HASH" &>/dev/null; then
                SUCCESS=$((SUCCESS + 1))
            else
                FAILED=$((FAILED + 1))
                echo "❌ Failed to pin: $HASH"
            fi
        fi
    done
    
    echo ""
    echo "✅ Restore completed!"
    echo "Successfully pinned: $SUCCESS"
    echo "Failed to pin: $FAILED"
    
    return 0
}

# Main function
main() {
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        show_help
        return 0
    fi
    
    # Process commands
    case "$1" in
        add)
            shift
            add_content "$@"
            ;;
        list)
            shift
            list_content "$@"
            ;;
        remove)
            shift
            remove_content "$@"
            ;;
        search)
            shift
            search_content "$@"
            ;;
        info)
            shift
            show_content_info "$@"
            ;;
        publish)
            shift
            publish_content "$@"
            ;;
        backup)
            shift
            backup_content "$@"
            ;;
        restore)
            shift
            restore_content "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Run '$0 help' for usage information"
            return 1
            ;;
    esac
}

# Run the main function with all arguments
main "$@" 