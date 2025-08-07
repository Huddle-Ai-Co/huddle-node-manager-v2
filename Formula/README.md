# Huddle IPFS Tap

A Homebrew tap for Huddle's IPFS node management tools.

## Available Formulas

### ipfs-node-manager

Huddle's easy IPFS node setup and management tool.

#### Installation

```bash
# Add the tap
brew tap huddle/ipfs

# Install the formula
brew install ipfs-node-manager
```

#### Usage

After installation, you can use the following commands:

```bash
# Set up a basic IPFS node
ipfs-setup

# Install and run the Huddle IPFS Node Manager API (optional)
cd $(brew --prefix ipfs-node-manager)
./scripts/ipfs-manager-install
cd ./api
./start.sh
```

The API will be available at http://localhost:8000

## What is IPFS?

IPFS (InterPlanetary File System) is a protocol and peer-to-peer network for storing and sharing data in a distributed file system. IPFS uses content-addressing to uniquely identify each file in a global namespace connecting all computing devices.

## Features

- Easy setup of IPFS nodes powered by Huddle
- Automatic configuration for persistence
- Management API for adding content and monitoring nodes
- No subscription costs - run your own infrastructure

## About HuddleAI Co.

HuddleAI Co. builds tools that make decentralized technologies accessible to everyone.

## License

MIT 