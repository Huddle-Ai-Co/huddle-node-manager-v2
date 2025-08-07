# IPFS Community Manager

This document covers the community functionality added to the IPFS Node Manager.

## Overview

The IPFS Community Manager provides tools for interacting with the IPFS network, connecting with peers, and participating in the IPFS community. It enables users to manage peer connections, publish and subscribe to topics, and work with IPFS clusters.

## Community Commands

The community functionality is accessible through the main helper script:

```bash
hnm community [command] [options]
```

### Available Commands

- **peers**: Show connected peers
- **connect [addr]**: Connect to a peer
- **disconnect [addr]**: Disconnect from a peer
- **bootstrap**: Show bootstrap nodes
- **bootstrap add [addr]**: Add a bootstrap node
- **bootstrap remove [addr]**: Remove a bootstrap node
- **info**: Show node information
- **bandwidth**: Show bandwidth statistics
- **publish [topic] [msg]**: Publish a message to a topic
- **subscribe [topic]**: Subscribe to a topic
- **topics**: List active pubsub topics
- **cluster status**: Show cluster status (requires ipfs-cluster-ctl)
- **cluster peers**: Show cluster peers (requires ipfs-cluster-ctl)

### Examples

```bash
# Show connected peers
./ipfs-helper.sh community peers

# Show detailed peer information
./ipfs-helper.sh community peers --detailed

# Connect to a peer
./ipfs-helper.sh community connect /ip4/1.2.3.4/tcp/4001/p2p/QmHash...

# Disconnect from a peer
./ipfs-helper.sh community disconnect /ip4/1.2.3.4/tcp/4001/p2p/QmHash...

# Show bootstrap nodes
./ipfs-helper.sh community bootstrap

# Add a bootstrap node
./ipfs-helper.sh community bootstrap add /ip4/1.2.3.4/tcp/4001/p2p/QmHash...

# Remove a bootstrap node
./ipfs-helper.sh community bootstrap remove /ip4/1.2.3.4/tcp/4001/p2p/QmHash...

# Show node information
./ipfs-helper.sh community info

# Show bandwidth statistics
./ipfs-helper.sh community bandwidth

# Publish a message to a topic
./ipfs-helper.sh community publish chat "Hello, IPFS world!"

# Subscribe to a topic
./ipfs-helper.sh community subscribe chat

# List active pubsub topics
./ipfs-helper.sh community topics

# Show cluster status (if ipfs-cluster-ctl is installed)
./ipfs-helper.sh community cluster status

# Show cluster peers (if ipfs-cluster-ctl is installed)
./ipfs-helper.sh community cluster peers
```

## Peer Management

The community manager allows you to view, connect to, and disconnect from peers in the IPFS network.

### Viewing Peers

```bash
# Basic peer list
./ipfs-helper.sh community peers

# Detailed peer information
./ipfs-helper.sh community peers --detailed
```

The detailed view provides additional information about each peer, including:
- Peer ID
- Connection latency
- Agent version
- Supported protocols

### Connecting to Peers

To connect to a specific peer:

```bash
./ipfs-helper.sh community connect /ip4/1.2.3.4/tcp/4001/p2p/QmHash...
```

This establishes a direct connection to the specified peer, which can be useful for:
- Accessing specific content
- Improving network connectivity
- Testing peer-to-peer connections

### Disconnecting from Peers

To disconnect from a specific peer:

```bash
./ipfs-helper.sh community disconnect /ip4/1.2.3.4/tcp/4001/p2p/QmHash...
```

## Bootstrap Node Management

Bootstrap nodes are used by IPFS to discover other peers in the network.

### Viewing Bootstrap Nodes

```bash
./ipfs-helper.sh community bootstrap
```

### Adding Bootstrap Nodes

```bash
./ipfs-helper.sh community bootstrap add /ip4/1.2.3.4/tcp/4001/p2p/QmHash...
```

### Removing Bootstrap Nodes

```bash
./ipfs-helper.sh community bootstrap remove /ip4/1.2.3.4/tcp/4001/p2p/QmHash...
```

## Node Information

To view detailed information about your IPFS node:

```bash
./ipfs-helper.sh community info
```

This displays:
- Node ID
- Node addresses
- Agent version
- Protocol version
- Public key

## Bandwidth Statistics

To view bandwidth usage statistics:

```bash
./ipfs-helper.sh community bandwidth
```

This shows:
- Total incoming data
- Total outgoing data
- Current incoming data rate
- Current outgoing data rate

## PubSub Messaging

IPFS includes a publish-subscribe (pubsub) system that allows nodes to send and receive messages on specific topics.

### Publishing Messages

```bash
./ipfs-helper.sh community publish [topic] [message]
```

For example:
```bash
./ipfs-helper.sh community publish chat "Hello, IPFS world!"
```

### Subscribing to Topics

```bash
./ipfs-helper.sh community subscribe [topic]
```

For example:
```bash
./ipfs-helper.sh community subscribe chat
```

This command will listen for messages on the specified topic until you press Ctrl+C to stop.

### Listing Active Topics

```bash
./ipfs-helper.sh community topics
```

## IPFS Cluster Management

If you have `ipfs-cluster-ctl` installed, you can manage IPFS clusters:

### Viewing Cluster Status

```bash
./ipfs-helper.sh community cluster status
```

### Viewing Cluster Peers

```bash
./ipfs-helper.sh community cluster peers
```

## Technical Details

The community functionality is implemented in the `ipfs-cluster-manager.sh` script, which provides a modular approach to managing peer connections and community interactions. This script can be used standalone or through the main helper script.

The system uses various IPFS commands to interact with peers, manage bootstrap nodes, and work with the pubsub system. It also provides integration with IPFS Cluster if the required tools are installed. 