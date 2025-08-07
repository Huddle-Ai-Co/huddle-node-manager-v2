#!/bin/bash

# Script to set up API key for Huddle Node Manager
# This script generates a random API key and saves it to the ~/.ipfs/huddleai_api_key file
# It also runs this in all test environments (Linux, WSL, MinGW, macOS)

set -e

echo "Setting up API key for Huddle Node Manager..."

# Function to generate a random API key
generate_api_key() {
    # Generate a 32-character random key
    openssl rand -hex 16
}

# Function to set up API key in a container
setup_api_key_in_container() {
    local container=$1
    local api_key=$2
    
    echo "Setting up API key in $container container..."
    
    # Create the .ipfs directory in the container
    docker exec $container bash -c "mkdir -p ~/.ipfs"
    
    # Save the API key to the container
    docker exec $container bash -c "echo '$api_key' > ~/.ipfs/huddleai_api_key"
    
    # Set proper permissions
    docker exec $container bash -c "chmod 600 ~/.ipfs/huddleai_api_key"
    
    # Verify the API key was saved
    docker exec $container bash -c "cat ~/.ipfs/huddleai_api_key"
    
    echo "API key set up successfully in $container container."
}

# Generate a random API key
API_KEY=$(generate_api_key)
echo "Generated API key: ${API_KEY:0:4}...${API_KEY: -4}"

# Set up API key in all environments
for env in "hnm-linux" "hnm-wsl" "hnm-mingw" "hnm-macos"; do
    # Check if the container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^$env$"; then
        setup_api_key_in_container $env $API_KEY
    else
        echo "Container $env not found, skipping..."
    fi
done

# Create a test script to verify the API key
cat > /tmp/verify_api_key.py << EOF
#!/usr/bin/env python3
import os
import sys

api_key_file = os.path.expanduser("~/.ipfs/huddleai_api_key")

if os.path.exists(api_key_file):
    with open(api_key_file, 'r') as f:
        api_key = f.read().strip()
        print(f"API key found: {api_key[:4]}...{api_key[-4:]}")
        sys.exit(0)
else:
    print("API key file not found")
    sys.exit(1)
EOF

# Run the verification script in all environments
for env in "hnm-linux" "hnm-wsl" "hnm-mingw" "hnm-macos"; do
    # Check if the container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^$env$"; then
        echo "Verifying API key in $env container..."
        docker cp /tmp/verify_api_key.py $env:/tmp/verify_api_key.py
        docker exec $env bash -c "python3 /tmp/verify_api_key.py"
    fi
done

echo "API key setup completed successfully!" 