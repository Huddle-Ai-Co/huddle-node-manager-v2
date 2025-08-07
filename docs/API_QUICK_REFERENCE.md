# HuddleAI API Quick Reference Guide

## 🚀 **Quick Start**

```bash
# Setup API key (first time)
./api_key_manager.sh setup

# Check system status
./api_key_manager.sh check

# Process a document
./ipfs-search-manager.sh search "document.pdf"

# Troubleshoot issues
./api_key_manager.sh troubleshoot
```

## 🔧 **Common Commands**

### **API Key Management**
```bash
./api_key_manager.sh check        # Quick status check
./api_key_manager.sh setup        # Interactive setup wizard
./api_key_manager.sh reset        # Replace existing key
./api_key_manager.sh info         # Show key information
./api_key_manager.sh troubleshoot # Full diagnostics
./api_key_manager.sh verify       # Test all services
```

### **Content Processing**
```bash
# Single file processing
./ipfs-search-manager.sh search "file.pdf"
./ipfs-search-manager.sh search "image.png"

# Batch processing
./batch_indexer.sh process_directory "~/Documents"
```

## 🐍 **Python Integration**

### **Basic Usage**
```python
from apim.client import client

# Verify API access
success, message = client.verify_api_key("embeddings")
if not success:
    print(f"API Error: {message}")
    exit(1)

# Generate embeddings
result = client.embeddings.embed_text("Hello world")
print(f"Embedding vector: {result}")

# Process image
enhanced = client.image_processor.enhance_image("photo.jpg")
```

### **Service-Specific Clients**
```python
# Embeddings
embeddings = client.embeddings
text_embedding = embeddings.embed_text("Sample text")
image_embedding = embeddings.embed_image("image.jpg")

# OCR
ocr = client.ocr
extracted_text = ocr.extract_text_from_document("document.pdf")

# Image Processing
processor = client.image_processor
objects = processor.detect_objects("photo.jpg")
enhanced = processor.enhance_image("photo.jpg")
```

## 🔐 **API Key Operations**

### **Shell Functions** (source api_key_manager.sh)
```bash
# Check if API key exists
if check_api_key; then
    echo "API key is available"
fi

# Get API key value
api_key=$(get_api_key)
echo "Key: ${api_key:0:8}..."

# Save new API key
save_api_key "your-new-key-here"

# Verify specific service
if verify_service "embeddings"; then
    echo "Embeddings service is working"
fi
```

### **Python Functions**
```python
from apim.common import api_key

# Get stored API key
key = api_key.get_api_key()

# Save new API key
api_key.save_api_key("your-new-key")

# Verify service
success, msg = api_key.verify_api_key("embeddings")

# Make direct API call
result, error = api_key.call_api("embeddings", "embed", 
                                method="POST", 
                                data={"text": "Hello"})
```

## 📁 **File Locations**

### **Configuration Files**
```
~/.ipfs/huddleai_api_key     # API key (chmod 600)
~/.ipfs/apim_config.json     # Service endpoints
~/.ipfs/embeddings/          # Cached embeddings
```

### **Key Scripts**
```
huddle-node-manager/
├── api_key_manager.sh       # Main API management
├── ipfs-search-manager.sh   # Content processing  
├── batch_indexer.sh         # Bulk operations
└── api/apim/
    ├── client.py            # Unified client
    └── common/api_key.py    # Core operations
```

## 🔍 **Service Status**

| Service | Status | Endpoint | Use Case |
|---------|--------|----------|----------|
| **Embeddings** | ✅ Working | `/embedding` | Text/image vectorization |
| **OCR** | ✅ Working | `/hocr` | Document text extraction |
| **NLP** | ⚠️ Partial | `/nlp` | Text analysis |
| **Transcriber** | ⚠️ Partial | `/parsing` | Audio transcription |

## 🛠️ **Troubleshooting**

### **Common Issues**
```bash
# API key not found
./api_key_manager.sh setup

# Service verification failed  
./api_key_manager.sh troubleshoot

# Permission denied
chmod 600 ~/.ipfs/huddleai_api_key

# Python import errors
cd huddle-node-manager && source nlp_venv/bin/activate
```

### **Error Codes**
| Code | Meaning | Solution |
|------|---------|----------|
| **401** | Invalid API key | Run `./api_key_manager.sh reset` |
| **404** | Service not found | Check service configuration |
| **429** | Rate limited | Wait and retry |
| **500** | Server error | Check service status |

## 📊 **Performance Tips**

### **Optimization**
- **Batch Processing**: Use `embed_batch` for multiple texts
- **Caching**: Results are cached in `~/.ipfs/embeddings/`
- **Concurrent**: Process multiple files in parallel
- **File Size**: Keep images under 10MB for best performance

### **Monitoring**
```bash
# Check service health
./api_key_manager.sh verify

# Monitor processing
tail -f ~/.ipfs/processing.log

# Check IPFS status
ipfs swarm peers | wc -l
```

## 🔄 **Integration Patterns**

### **Shell Script Integration**
```bash
#!/bin/bash
source "$(dirname "$0")/api_key_manager.sh"

# Ensure API key is available
if ! check_api_key; then
    echo "Please setup API key first"
    exit 1
fi

# Your processing logic here
process_files() {
    for file in "$@"; do
        ./ipfs-search-manager.sh search "$file"
    done
}
```

### **Python Script Integration**
```python
#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'api'))

from apim.client import client

def main():
    # Verify API access
    success, message = client.verify_api_key()
    if not success:
        print(f"API Error: {message}")
        return 1
    
    # Your processing logic here
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

## 📞 **Support**

### **Getting Help**
- **Documentation**: See `API_ARCHITECTURE.md`
- **Troubleshooting**: Run `./api_key_manager.sh troubleshoot`
- **Logs**: Check `~/.ipfs/` directory for log files
- **Configuration**: Inspect `~/.ipfs/apim_config.json`

### **Common Workflows**
```bash
# Daily development workflow
./api_key_manager.sh check && \
./ipfs-search-manager.sh search "test.pdf" && \
echo "✅ System working"

# Reset everything
./api_key_manager.sh reset && \
rm -rf ~/.ipfs/embeddings/* && \
echo "🔄 System reset complete"
```

---

*Keep this reference handy for quick lookups during development!* 