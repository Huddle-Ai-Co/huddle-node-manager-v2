#!/bin/bash

# Wrapper script to run Python commands in virtual environment
VENV_DIR="hnm_env"

if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found at $VENV_DIR"
    exit 1
fi

# Activate virtual environment and run the command
source "$VENV_DIR/bin/activate"
exec "$@" 