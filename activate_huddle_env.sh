#!/bin/bash

# Huddle Node Manager Environment Activation Script
echo "🚀 Activating Huddle Node Manager Environment..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate the virtual environment
source "$SCRIPT_DIR/hnm_env/bin/activate"

# Set environment variables
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Set production path environment variable
export HNM_PRODUCTION_PATH="$HOME/.huddle-node-manager"
export HNM_BUNDLED_MODELS_PATH="$HOME/.huddle-node-manager/bundled_models"

echo "✅ Environment activated successfully!"
echo "📁 Working directory: $SCRIPT_DIR"
echo "🐍 Python: $(which python)"
echo "📦 Virtual environment: $VIRTUAL_ENV"
echo "🏠 Production path: $HNM_PRODUCTION_PATH"
echo "🤖 Bundled models: $HNM_BUNDLED_MODELS_PATH"

# Show available packages
echo ""
echo "📋 Installed packages include:"
echo "   • PyTorch (torch, torchvision, torchaudio)"
echo "   • Audio processing (librosa, soundfile, pyannote.audio, whisper)"
echo "   • Image processing (opencv-python, Pillow, ultralytics)"
echo "   • Machine learning (transformers, scikit-learn, scikit-image)"
echo "   • OCR (pytesseract, easyocr)"
echo "   • Utilities (numpy, scipy, tqdm, requests)"

echo ""
echo "💡 To deactivate, run: deactivate"
echo "💡 To run a Python script: python your_script.py"
echo "💡 To ensure all dependencies are installed: python setup_environment.py"
echo "💡 To launch GGUF server: python $HNM_BUNDLED_MODELS_PATH/optimized_gguf_server.py"
echo "💡 To launch resource server: python $HNM_BUNDLED_MODELS_PATH/optimized_resource_server.py" 