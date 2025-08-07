# 🤖 HNM Bundled Models Setup

## Overview

The HNM Bundled Models Setup automatically downloads and configures all required AI models and components for Huddle Node Manager. This includes models from Hugging Face, direct downloads from GitHub, and proper configuration of all service directories.

## ✨ What Gets Installed

### 🧠 **AI Models from Hugging Face:**
- **`llama-3.2-3b-quantized-q4km/`** - Quantized LLaMA 3.2 3B model (~2.5GB)
  - Source: `microsoft/Llama-3.2-3B-Instruct-GGUF` 
  - Includes: `model_config.json` with optimized settings
- **`metricgan-plus-voicebank/`** - Advanced noise cancellation (~500MB)
  - Source: `JorisCos/MetricGAN-Plus_voicebank`
- **`sepformer-dns4-16k-enhancement/`** - Speech enhancement (~300MB) 
  - Source: `speechbrain/sepformer-dns4-16k-enhancement`
- **`whisper/`** - Speech recognition (~150MB)
  - Source: `openai/whisper-base`

### 🎯 **Direct Downloads:**
- **`yoloe_11l.pt`** - Object detection model (~50MB)
  - Source: Ultralytics YOLO11 official release
- **`RealESRGAN_x4plus.pth`** - Image upscaling model (~65MB)
  - Source: Real-ESRGAN official release

### 📁 **Directory Structure Created:**
```
api/open-processing/bundled_models/
├── .gitignore                          # Excludes large files from git
├── .cache/                             # Hugging Face download cache
├── llama-3.2-3b-quantized-q4km/
│   ├── Llama-3.2-3B-Instruct-Q4_K_M.gguf
│   └── model_config.json              # Optimized loading config
├── metricgan-plus-voicebank/
├── sepformer-dns4-16k-enhancement/
├── whisper/
├── yoloe_11l.pt
├── RealESRGAN_x4plus.pth
├── optimized_gguf_server.py           # Existing server
└── optimized_resource_server.py       # Existing server

api/open-processing/
├── mira-control-app/                   # Electron control interface
├── image_processing_service/           # Image AI service
├── embeddings_service/                 # Embeddings service
└── audio_service/                      # Audio processing service

api/apim/                               # API management components
```

## 🚀 Usage Options

### **During HNM Installation:**
When you run `./install-hnm.sh`, you'll be prompted:
```
🤖 AI Model Setup Options:
  1) Download all models (~2-5GB) - Complete AI functionality
  2) Skip large models (~50MB) - Basic functionality only  
  3) Skip model setup entirely
```

### **Standalone Setup:**
```bash
# Complete setup with all models
python3 setup_bundled_models.py --download-models

# Minimal setup (skip large models)
python3 setup_bundled_models.py --skip-large-models

# Quick wrapper script
./setup_models.sh --download-models
```

### **Interactive Setup:**
```bash
# Run with prompts
python3 setup_bundled_models.py
```

## 📊 **Download Sizes & Times**

| Component | Size | Download Time* |
|-----------|------|----------------|
| LLaMA 3.2 3B Quantized | ~2.5GB | 5-15 minutes |
| MetricGAN+ | ~500MB | 1-3 minutes |
| SepFormer DNS4 | ~300MB | 1-2 minutes |
| Whisper Base | ~150MB | 30-60 seconds |
| YOLO11 Large | ~50MB | 10-30 seconds |
| RealESRGAN | ~65MB | 10-30 seconds |
| **Total (Complete)** | **~3.5GB** | **8-20 minutes** |
| **Total (Minimal)** | **~115MB** | **1-2 minutes** |

*Times vary based on internet connection

## 🔧 **Technical Details**

### **Dependencies Automatically Installed:**
- `huggingface_hub[cli]` - For model downloads
- `transformers` - Model loading framework
- `torch` - Deep learning backend
- `speechbrain` - Audio processing models
- `ultralytics` - YOLO models
- `fastapi`, `uvicorn` - Server frameworks
- `llama-cpp-python` - LLaMA model inference
- `gguf` - Model format support

### **Configuration Files:**
Each model gets proper configuration:
```json
// llama-3.2-3b-quantized-q4km/model_config.json
{
  "model_name": "llama-3.2-3b-quantized-q4km",
  "model_type": "llama",
  "quantization": "Q4_K_M",
  "hardware_requirements": {
    "min_ram_gb": 4,
    "recommended_ram_gb": 8,
    "gpu_memory_gb": 2
  },
  "loading_config": {
    "n_ctx": 8192,
    "n_batch": 512,
    "f16_kv": true
  }
}
```

### **Service Directory Setup:**
- Creates `__init__.py` files for Python imports
- Ensures proper directory structure
- Configures service dependencies

## 🛠️ **Advanced Usage**

### **Custom Model Configuration:**
Edit `setup_bundled_models.py` to add your own models:
```python
self.huggingface_models["my-custom-model"] = {
    "repo_id": "organization/model-name",
    "type": "full_repo"
}
```

### **Skip Specific Models:**
```python
# In setup_bundled_models.py, comment out models you don't need
# "whisper": {
#     "repo_id": "openai/whisper-base", 
#     "type": "full_repo"
# },
```

### **Use Different Model Variants:**
```python
# For LLaMA, change to different quantization
"filename": "Llama-3.2-3B-Instruct-Q8_0.gguf"  # Higher quality, larger size
```

## 🔍 **Verification**

The setup automatically verifies installation:
```
✅ llama-3.2-3b-quantized-q4km
✅ metricgan-plus-voicebank  
✅ sepformer-dns4-16k-enhancement
✅ whisper
✅ yoloe_11l.pt (50.2MB)
✅ RealESRGAN_x4plus.pth (65.1MB)
✅ optimized_gguf_server.py
✅ .gitignore
```

## 🚨 **Troubleshooting**

### **Common Issues:**

**"huggingface-cli not found"**
- Solution: Automatically installed during setup

**"Failed to download model"**
- Check internet connection
- Verify Hugging Face Hub access
- Try again - downloads resume automatically

**"Permission denied"**
- Ensure write access to current directory
- Check disk space (need ~4GB free)

**"Import errors after setup"**
- Restart terminal/Python environment
- Check virtual environment is activated

### **Manual Recovery:**
```bash
# Re-run just the model downloads
python3 setup_bundled_models.py --download-models

# Skip problematic models
python3 setup_bundled_models.py --skip-large-models

# Clean and retry
rm -rf api/open-processing/bundled_models/.cache
python3 setup_bundled_models.py --download-models
```

## 📦 **Integration with Self-Extracting Installer**

The bundled models setup is automatically included in the self-extracting installer:

```bash
# Build installer with model setup included
./build-release.sh

# Generated installer includes setup_bundled_models.py
./huddle-node-manager-v2.0.0-installer.run
```

Users get the complete model setup capability in the single-file installer!

## 🎯 **Best Practices**

1. **Complete Install Recommended:** Download all models for full functionality
2. **Disk Space:** Ensure 5GB+ free space before starting
3. **Internet:** Stable connection required for large downloads
4. **Patience:** Initial setup takes time but models are cached
5. **Updates:** Re-run setup when new models are added

## 🔮 **Future Enhancements**

- **Model Updates:** Automatic version checking and updates
- **Custom Endpoints:** Support for private model repositories
- **Optimization:** Automatic hardware-specific model selection
- **Caching:** Shared model cache across multiple installations
- **Compression:** Better compression for faster downloads

The bundled models system ensures HNM has enterprise-grade AI capabilities out of the box! 🚀 