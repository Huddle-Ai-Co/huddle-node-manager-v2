#!/bin/bash

# HNM Script Runner - Runs Python scripts with the correct virtual environment
# Usage: run_hnm_script.sh <script_name> [arguments]

SCRIPT_NAME="$1"
shift  # Remove the first argument (script name)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the virtual environment in the Downloads directory
VENV_PATH="/Users/tangj4/Downloads/huddle-node-manager/hnm_env"

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    echo "❌ Virtual environment not found: $VENV_PATH"
    echo "Please run the installation script first: ./install-hnm-complete.sh"
    exit 1
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Set environment variables
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"
export HNM_PRODUCTION_PATH="$HOME/.huddle-node-manager"
export HNM_BUNDLED_MODELS_PATH="$HOME/.huddle-node-manager/bundled_models"

# Run the script
if [ -f "$SCRIPT_DIR/scripts/$SCRIPT_NAME" ]; then
    python3 "$SCRIPT_DIR/scripts/$SCRIPT_NAME" "$@"
elif [ -f "$SCRIPT_NAME" ]; then
    python3 "$SCRIPT_NAME" "$@"
else
    echo "❌ Script not found: $SCRIPT_NAME"
    echo "Available scripts in $SCRIPT_DIR/scripts/:"
    ls -la "$SCRIPT_DIR/scripts/"
    exit 1
fi 