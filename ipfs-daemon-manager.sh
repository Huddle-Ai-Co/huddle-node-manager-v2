#!/bin/bash

# HNM (Huddle Node Manager) - IPFS Daemon Manager
# Advanced daemon management for the modern Huddle Node Manager
# This script provides commands to start, stop, restart, and check the status of the IPFS daemon

# Function to display banner
display_banner() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                      HUDDLE NODE MANAGER                       │
│                                                                 │
│  🏠 Daemon Manager                                              │
│  🔄 IPFS Daemon Control                                         │
│  ⬆️  Upgraded from IPFS Daemon Manager                         │
│  🔧 Part of Huddle Node Manager Suite                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

# Function to get appropriate command prefix based on calling context
get_command_prefix() {
    # Always use modern command format in help text for consistency
    echo "hnm"
}

# Function to show help message
show_help() {
    display_banner
    echo "🏠 HNM (Huddle Node Manager) - Daemon Manager"
    echo "============================================"
    echo "🔄 Advanced IPFS daemon management with enhanced UX"
    echo ""
    
    # Use context-aware command prefix
    local CMD_PREFIX=$(get_command_prefix)
    echo "Usage: $CMD_PREFIX [command] [options]"
    echo ""
    echo "🎯 Commands:"
    echo "  start                  - Start the IPFS daemon"
    echo "  stop                   - Stop the IPFS daemon"
    echo "  restart                - Restart the IPFS daemon"
    echo "  status                 - Check if the IPFS daemon is running"
    echo "  help                   - Show this help message"
    echo ""
    echo "⚙️  Options:"
    echo "  --quiet, -q            - Minimal output"
    echo "  --verbose, -v          - Verbose output"
    echo ""
    echo "💡 Examples:"
    echo "  $CMD_PREFIX start"
    echo "  $CMD_PREFIX status"
    echo "  $CMD_PREFIX stop"
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

# Function to handle lock file
handle_lock_file() {
    if [ -f ~/.ipfs/repo.lock ]; then
        # Check if there's actually an IPFS process running
        if ! check_daemon_running; then
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

# Function to create log directory if it doesn't exist
ensure_log_directory() {
    if [ ! -d ~/.ipfs/logs ]; then
        mkdir -p ~/.ipfs/logs
        echo "Created log directory at ~/.ipfs/logs"
    fi
}

# Function to start the IPFS daemon
start_daemon() {
    echo "Attempting to start IPFS daemon..."
    
    # Check if daemon is already running
    if check_daemon_running; then
        echo "✅ IPFS daemon is already running"
        return 0
    fi
    
    # Check for stale lock file
    handle_lock_file || return 1
    
    # Ensure log directory exists
    ensure_log_directory
    
    # Start daemon in the background
    echo "🚀 Starting IPFS daemon..."
    nohup ipfs daemon --enable-gc > ~/.ipfs/logs/daemon.log 2>&1 &
    
    # Wait for daemon to start (max 10 seconds)
    echo "Waiting for daemon to start..."
    for i in {1..10}; do
        sleep 1
        if check_daemon_running; then
            echo "✅ IPFS daemon started successfully"
            return 0
        fi
        echo -n "."
    done
    
    echo ""
    echo "❌ Failed to start IPFS daemon. Check logs with '$0 logs'"
    return 1
}

# Function to stop the IPFS daemon
stop_daemon() {
    echo "Attempting to stop IPFS daemon..."
    
    # Check if daemon is running
    if ! check_daemon_running; then
        echo "ℹ️ IPFS daemon is not running"
        return 0
    fi
    
    # Try graceful shutdown first
    echo "🛑 Stopping IPFS daemon gracefully..."
    ipfs shutdown
    
    # Wait for daemon to stop (max 10 seconds)
    echo "Waiting for daemon to stop..."
    for i in {1..10}; do
        sleep 1
        if ! check_daemon_running; then
            echo "✅ IPFS daemon stopped successfully"
            return 0
        fi
        echo -n "."
    done
    
    echo ""
    echo "⚠️ Daemon didn't shut down gracefully. Force killing..."
    pkill -x ipfs
    sleep 2
    
    if check_daemon_running; then
        echo "❌ Failed to stop IPFS daemon"
        return 1
    else
        echo "✅ IPFS daemon stopped (force kill)"
        return 0
    fi
}

# Function to restart the IPFS daemon
restart_daemon() {
    echo "Restarting IPFS daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

# Function to check daemon status
check_status() {
    echo "IPFS Daemon Status:"
    echo "------------------"
    
    if check_daemon_running; then
        echo "✅ IPFS daemon is running"
        
        # Get more detailed information
        echo "Connected to $(ipfs swarm peers | wc -l | tr -d ' ') peers"
        
        # Get process information
        PID=$(pgrep -x "ipfs")
        if [ ! -z "$PID" ]; then
            echo "Process ID: $PID"
            # Use a more compatible ps format that works on both macOS and Linux
            UPTIME=$(ps -p $PID -o time | grep -v TIME)
            echo "Uptime: $UPTIME"
        fi
        
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
        
        # Extract host and port from API address
        HOST=$(echo "$API" | grep -o '/ip[46]/[^/]*' | head -1 | cut -d'/' -f3)
        PORT=$(echo "$API" | grep -o '/tcp/[0-9]*' | head -1 | cut -d'/' -f3)
        
        if [ ! -z "$HOST" ] && [ ! -z "$PORT" ]; then
            echo "WebUI available at: http://$HOST:$PORT/webui"
        fi
    else
        echo "❌ IPFS daemon is not running"
        
        # Check for lock file
        if [ -f ~/.ipfs/repo.lock ]; then
            echo "⚠️ Lock file exists. You may need to run '$0 clean' before starting the daemon."
        else
            echo "You can start it with: $0 start"
        fi
    fi
}

# Function to show logs
show_logs() {
    LOG_FILE=~/.ipfs/logs/daemon.log
    
    if [ -f "$LOG_FILE" ]; then
        echo "Last 50 lines of IPFS daemon logs:"
        echo "--------------------------------"
        tail -n 50 "$LOG_FILE"
    else
        echo "❌ No log file found at $LOG_FILE"
        echo "The daemon may not have been started with this script."
    fi
}

# Function to clean stale lock files
clean_lock_files() {
    if check_daemon_running; then
        echo "❌ Cannot clean lock files while daemon is running."
        echo "Please stop the daemon first with: $0 stop"
        return 1
    fi
    
    if [ -f ~/.ipfs/repo.lock ]; then
        echo "Found lock file at ~/.ipfs/repo.lock"
        echo "Removing lock file..."
        rm -f ~/.ipfs/repo.lock
        echo "✅ Lock file removed"
    else
        echo "No lock file found."
    fi
    
    echo "✅ Clean completed"
    return 0
}

# Main function
main() {
    case "$1" in
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            restart_daemon
            ;;
        status)
            check_status
            ;;
        logs)
            show_logs
            ;;
        clean)
            clean_lock_files
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_help
            ;;
    esac
}

# Run the main function with all arguments
main "$@" 