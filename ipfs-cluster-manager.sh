#!/bin/bash
#
# IPFS Cluster Manager
# A utility for managing IPFS clusters and community interactions
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display banner
display_banner() {
cat << "EOF"
┌─────────────────────────────────────────────────────────────────┐
│                      HUDDLE NODE MANAGER                       │
│                                                                 │
│  👥 Community Manager                                           │
│  👥 Connect and Collaborate | IPFS Peer Management             │
│  ⬆️  Upgraded from IPFS Cluster Manager                        │
│  🔧 Part of Huddle Node Manager Suite                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""
}

# Function to check if IPFS daemon is running
check_daemon() {
    if ! ipfs swarm peers &>/dev/null; then
        echo -e "${RED}❌ IPFS daemon is not running${NC}"
        echo -e "${YELLOW}Try starting the daemon with:${NC} hnm start"
        return 1
    else
        echo -e "${GREEN}✅ IPFS daemon is running${NC}"
        return 0
    fi
}

# Function to show peers
show_peers() {
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving peer information...${NC}"
    
    # Get peer count
    PEER_COUNT=$(ipfs swarm peers | wc -l)
    echo -e "${GREEN}Connected to $PEER_COUNT peers${NC}"
    
    # Check for detailed flag
    if [[ "$*" == *"--detailed"* ]]; then
        echo -e "${BLUE}Detailed peer information:${NC}"
        
        # Get detailed peer info
        ipfs swarm peers -v | while read -r line; do
            PEER_ID=$(echo "$line" | awk '{print $1}')
            LATENCY=$(ipfs ping -n 1 "$PEER_ID" 2>/dev/null | grep -o "Average latency: [0-9.]*" | awk '{print $3}')
            
            echo -e "${CYAN}Peer:${NC} $line"
            if [ ! -z "$LATENCY" ]; then
                echo -e "${CYAN}Latency:${NC} $LATENCY ms"
            fi
            
            # Try to get additional info
            ipfs id "$PEER_ID" -f='${NC}${YELLOW}Agent:${NC} ${agent}\n${YELLOW}Protocols:${NC} ${protocols}' 2>/dev/null
            echo ""
        done
    else
        # Just show peer list
        echo -e "${BLUE}Peer list:${NC}"
        ipfs swarm peers
    fi
    
    echo ""
    echo -e "${YELLOW}💡 Tip:${NC} Use '$0 peers --detailed' for more information"
    
    return 0
}

# Function to connect to a peer
connect_peer() {
    # Check if we have a peer address
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No peer address specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 connect [peer_address]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    PEER_ADDR="$1"
    
    echo -e "${BLUE}🔌 Connecting to peer: $PEER_ADDR${NC}"
    
    # Try to connect
    if ipfs swarm connect "$PEER_ADDR"; then
        echo -e "${GREEN}✅ Successfully connected to peer${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to connect to peer${NC}"
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo -e "  - The peer address is incorrect"
        echo -e "  - The peer is not online"
        echo -e "  - Network connectivity issues"
        echo -e "  - Firewall blocking the connection"
        return 1
    fi
}

# Function to disconnect from a peer
disconnect_peer() {
    # Check if we have a peer address
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No peer address specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 disconnect [peer_address]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    PEER_ADDR="$1"
    
    echo -e "${BLUE}🔌 Disconnecting from peer: $PEER_ADDR${NC}"
    
    # Try to disconnect
    if ipfs swarm disconnect "$PEER_ADDR"; then
        echo -e "${GREEN}✅ Successfully disconnected from peer${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to disconnect from peer${NC}"
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo -e "  - The peer address is incorrect"
        echo -e "  - You are not connected to this peer"
        return 1
    fi
}

# Function to show bootstrap nodes
show_bootstrap() {
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving bootstrap nodes...${NC}"
    
    # Get bootstrap nodes
    BOOTSTRAP=$(ipfs bootstrap list)
    BOOTSTRAP_COUNT=$(echo "$BOOTSTRAP" | wc -l)
    
    echo -e "${GREEN}Found $BOOTSTRAP_COUNT bootstrap nodes${NC}"
    echo -e "${BLUE}Bootstrap nodes:${NC}"
    echo "$BOOTSTRAP"
    
    return 0
}

# Function to add a bootstrap node
add_bootstrap() {
    # Check if we have a bootstrap address
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No bootstrap address specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 bootstrap add [bootstrap_address]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    BOOTSTRAP_ADDR="$1"
    
    echo -e "${BLUE}🔌 Adding bootstrap node: $BOOTSTRAP_ADDR${NC}"
    
    # Try to add bootstrap node
    if ipfs bootstrap add "$BOOTSTRAP_ADDR"; then
        echo -e "${GREEN}✅ Successfully added bootstrap node${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to add bootstrap node${NC}"
        return 1
    fi
}

# Function to remove a bootstrap node
remove_bootstrap() {
    # Check if we have a bootstrap address
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No bootstrap address specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 bootstrap remove [bootstrap_address]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    BOOTSTRAP_ADDR="$1"
    
    echo -e "${BLUE}🔌 Removing bootstrap node: $BOOTSTRAP_ADDR${NC}"
    
    # Try to remove bootstrap node
    if ipfs bootstrap rm "$BOOTSTRAP_ADDR"; then
        echo -e "${GREEN}✅ Successfully removed bootstrap node${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to remove bootstrap node${NC}"
        return 1
    fi
}

# Function to show node information
show_node_info() {
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving node information...${NC}"
    
    # Get node ID
    NODE_ID=$(ipfs id -f="<id>" 2>/dev/null)
    echo -e "${CYAN}Node ID:${NC} $NODE_ID"
    
    # Get node addresses
    echo -e "${CYAN}Addresses:${NC}"
    ipfs id -f="<addrs>" | tr -d '[]' | tr ',' '\n' | sed 's/^ */  /'
    
    # Get agent version
    AGENT=$(ipfs id -f="<agent_version>")
    echo -e "${CYAN}Agent:${NC} $AGENT"
    
    # Get protocol version
    PROTOCOL=$(ipfs id -f="<protocol_version>")
    echo -e "${CYAN}Protocol:${NC} $PROTOCOL"
    
    # Get public key
    PUBKEY=$(ipfs id -f="<public_key>")
    echo -e "${CYAN}Public Key:${NC} $PUBKEY"
    
    return 0
}

# Function to show bandwidth stats
show_bandwidth() {
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving bandwidth statistics...${NC}"
    
    # Get bandwidth stats
    STATS=$(ipfs stats bw)
    
    # Parse and display stats
    TOTAL_IN=$(echo "$STATS" | grep "TotalIn" | awk '{print $2}')
    TOTAL_OUT=$(echo "$STATS" | grep "TotalOut" | awk '{print $2}')
    RATE_IN=$(echo "$STATS" | grep "RateIn" | awk '{print $2}')
    RATE_OUT=$(echo "$STATS" | grep "RateOut" | awk '{print $2}')
    
    # Convert to human-readable format
    TOTAL_IN_HR=$(numfmt --to=iec-i "$TOTAL_IN")
    TOTAL_OUT_HR=$(numfmt --to=iec-i "$TOTAL_OUT")
    
    echo -e "${CYAN}Total In:${NC} $TOTAL_IN_HR"
    echo -e "${CYAN}Total Out:${NC} $TOTAL_OUT_HR"
    echo -e "${CYAN}Rate In:${NC} $RATE_IN B/s"
    echo -e "${CYAN}Rate Out:${NC} $RATE_OUT B/s"
    
    return 0
}

# Function to publish a message to pubsub
publish_message() {
    # Check if we have a topic and message
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}❌ Error: Topic or message not specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 publish [topic] [message]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    TOPIC="$1"
    MESSAGE="$2"
    
    echo -e "${BLUE}📢 Publishing message to topic: $TOPIC${NC}"
    
    # Try to publish message
    if echo "$MESSAGE" | ipfs pubsub pub "$TOPIC"; then
        echo -e "${GREEN}✅ Message published successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to publish message${NC}"
        return 1
    fi
}

# Function to subscribe to a pubsub topic
subscribe_topic() {
    # Check if we have a topic
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: No topic specified${NC}"
        echo -e "${YELLOW}Usage:${NC} $0 subscribe [topic]"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    TOPIC="$1"
    
    echo -e "${BLUE}🔔 Subscribing to topic: $TOPIC${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop listening${NC}"
    
    # Subscribe to topic
    ipfs pubsub sub "$TOPIC"
    
    return 0
}

# Function to list pubsub topics
list_topics() {
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving pubsub topics...${NC}"
    
    # Get topics
    TOPICS=$(ipfs pubsub ls)
    
    if [ -z "$TOPICS" ]; then
        echo -e "${YELLOW}No active topics found${NC}"
    else
        echo -e "${GREEN}Active topics:${NC}"
        echo "$TOPICS"
    fi
    
    return 0
}

# Function to show cluster status (if ipfs-cluster-ctl is available)
show_cluster_status() {
    # Check if ipfs-cluster-ctl is installed
    if ! command -v ipfs-cluster-ctl &> /dev/null; then
        echo -e "${RED}❌ ipfs-cluster-ctl is not installed${NC}"
        echo -e "${YELLOW}Install it with:${NC} go get github.com/ipfs/ipfs-cluster/ipfs-cluster-ctl"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving cluster status...${NC}"
    
    # Get cluster status
    if ipfs-cluster-ctl status; then
        return 0
    else
        echo -e "${RED}❌ Failed to get cluster status${NC}"
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo -e "  - IPFS Cluster is not running"
        echo -e "  - You are not connected to any cluster"
        return 1
    fi
}

# Function to show cluster peers (if ipfs-cluster-ctl is available)
show_cluster_peers() {
    # Check if ipfs-cluster-ctl is installed
    if ! command -v ipfs-cluster-ctl &> /dev/null; then
        echo -e "${RED}❌ ipfs-cluster-ctl is not installed${NC}"
        echo -e "${YELLOW}Install it with:${NC} go get github.com/ipfs/ipfs-cluster/ipfs-cluster-ctl"
        return 1
    fi
    
    # Ensure daemon is running
    check_daemon || return 1
    
    echo -e "${BLUE}🔍 Retrieving cluster peers...${NC}"
    
    # Get cluster peers
    if ipfs-cluster-ctl peers ls; then
        return 0
    else
        echo -e "${RED}❌ Failed to get cluster peers${NC}"
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo -e "  - IPFS Cluster is not running"
        echo -e "  - You are not connected to any cluster"
        return 1
    fi
}

# Function to get appropriate command prefix based on calling context
get_command_prefix() {
    # Always use modern command format in help text for consistency
    echo "hnm community"
}

# Function to show help message
show_help() {
    display_banner
    echo "🏠 HNM (Huddle Node Manager) - Community Manager"
    echo "=============================================="
    echo "🌍 Advanced IPFS peer and community management"
    echo ""
    
    # Use context-aware command prefix
    local CMD_PREFIX=$(get_command_prefix)
    echo "Usage: $CMD_PREFIX [command] [options]"
    echo ""
    echo "🎯 Commands:"
    echo "  peers                  - List connected peers"
    echo "  connect [peer]         - Connect to a specific peer"
    echo "  bootstrap              - Manage bootstrap nodes"
    echo "  swarm                  - Manage swarm connections"
    echo "  stats                  - Show network statistics"
    echo "  help                   - Show this help message"
    echo ""
    echo "⚙️  Options:"
    echo "  --quiet, -q            - Minimal output"
    echo "  --verbose, -v          - Verbose output"
    echo "  --json                 - Output in JSON format"
    echo ""
    echo "💡 Examples:"
    echo "  $CMD_PREFIX peers"
    echo "  $CMD_PREFIX connect /ip4/1.2.3.4/tcp/4001/p2p/QmHash..."
    echo "  $CMD_PREFIX bootstrap list"
    echo ""
    echo "🚀 Command Format:"
    echo "   This tool is part of the Huddle Node Manager (HNM) suite"
    echo "   All operations can be performed using the '$CMD_PREFIX' prefix"
}

# Main function
main() {
    # No arguments, show help
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # Parse command
    COMMAND="$1"
    shift
    
    case "$COMMAND" in
        peers)
            show_peers "$@"
            ;;
        connect)
            connect_peer "$1"
            ;;
        disconnect)
            disconnect_peer "$1"
            ;;
        bootstrap)
            if [ -z "$1" ]; then
                show_bootstrap
            else
                case "$1" in
                    add)
                        add_bootstrap "$2"
                        ;;
                    remove|rm)
                        remove_bootstrap "$2"
                        ;;
                    *)
                        echo -e "${RED}❌ Unknown bootstrap command: $1${NC}"
                        echo -e "${YELLOW}Valid commands:${NC} add, remove"
                        exit 1
                        ;;
                esac
            fi
            ;;
        info)
            show_node_info
            ;;
        bandwidth|bw)
            show_bandwidth
            ;;
        publish|pub)
            publish_message "$1" "$2"
            ;;
        subscribe|sub)
            subscribe_topic "$1"
            ;;
        topics)
            list_topics
            ;;
        cluster)
            if [ -z "$1" ]; then
                echo -e "${RED}❌ Error: No cluster command specified${NC}"
                echo -e "${YELLOW}Valid commands:${NC} status, peers"
                exit 1
            else
                case "$1" in
                    status)
                        show_cluster_status
                        ;;
                    peers)
                        show_cluster_peers
                        ;;
                    *)
                        echo -e "${RED}❌ Unknown cluster command: $1${NC}"
                        echo -e "${YELLOW}Valid commands:${NC} status, peers"
                        exit 1
                        ;;
                esac
            fi
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
            show_help
            exit 1
            ;;
    esac
    
    exit $?
}

# If this script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 