#!/usr/bin/env python3
"""
Huddle Node Manager - Comprehensive Installation Verification
Run this after installation to verify everything works correctly
"""

import os
import sys
import time
import json
from pathlib import Path

# Color output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

def log_info(msg):
    print(f"{Colors.BLUE}ℹ️  {msg}{Colors.NC}")

def log_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.NC}")

def log_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.NC}")

def log_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.NC}")

def log_step(msg):
    print(f"{Colors.CYAN}🔄 {msg}{Colors.NC}")

def check_file_access(filepath, description):
    """Check if file exists and is accessible"""
    if os.path.exists(filepath):
        try:
            size = os.path.getsize(filepath)
            # Test read access by opening file
            with open(filepath, 'rb') as f:
                f.read(1024)  # Read first KB to confirm access
            
            if size > 1024**3:  # > 1GB
                size_str = f'{size / (1024**3):.1f}GB'
            elif size > 1024**2:  # > 1MB  
                size_str = f'{size / (1024**2):.1f}MB'
            elif size > 1024:  # > 1KB
                size_str = f'{size / 1024:.1f}KB'
            else:
                size_str = f'{size}B'
                
            log_success(f"{description}: {size_str}")
            return True
        except Exception as e:
            log_error(f"{description}: Error accessing - {e}")
            return False
    else:
        log_warning(f"{description}: Not found")
        return False

def check_bundled_models():
    """Check bundled models installation"""
    log_step("Checking bundled models...")
    
    # PRODUCTION PATH: Check standardized installation location
    model_base = str(Path.home() / ".huddle-node-manager" / "bundled_models")
    
    if not os.path.exists(model_base):
        log_error(f"Bundled models directory not found: {model_base}")
        return False
    
    log_success(f"✓ Bundled models directory exists: {model_base}")
    
    # Check for key models
    model_checks = [
        ('llama-3.2-3b-quantized-q4km', 'Language Model'),
        ('metricgan-plus-voicebank', 'Audio Enhancement'),
        ('sepformer-dns4-16k-enhancement', 'Speech Enhancement'),
        ('whisper', 'Speech Recognition'),
        ('paraphrase-multilingual-MiniLM-L12-v2', 'Multilingual Transformer'),
        ('xlm-roberta-language-detection', 'Language Detection'),
        ('florence-2-large', 'Vision-Language Model'),
        ('surya-ocr', 'OCR Model'),
        ('NeuroKit', 'Medical Analysis'),
    ]
    
    for model_name, description in model_checks:
        model_path = os.path.join(model_base, model_name)
        if os.path.exists(model_path):
            log_success(f"✓ {model_name} ({description})")
        else:
            log_warning(f"⚠️ {model_name} ({description}) not found")
    
    # Check for direct download models
    direct_models = [
        ('yoloe_11l.pt', 'YOLO Object Detection'),
        ('yoloe-11l-seg.pt', 'YOLO Segmentation'),
        ('RealESRGAN_x4plus.pth', 'Image Super-Resolution'),
    ]
    
    for model_name, description in direct_models:
        model_path = os.path.join(model_base, model_name)
        if os.path.exists(model_path):
            log_success(f"✓ {model_name} ({description})")
        else:
            log_warning(f"⚠️ {model_name} ({description}) not found")
    
    return True

def test_dependencies():
    """Test core dependencies"""
    print(f"\n{Colors.PURPLE}📦 Testing Dependencies...{Colors.NC}")
    
    dependencies = [
        ('torch', 'PyTorch'),
        ('transformers', 'Hugging Face Transformers'),
        ('llama_cpp', 'llama-cpp-python'),
        ('librosa', 'Librosa Audio'),
        ('PIL', 'Pillow Image Processing'),
        ('cv2', 'OpenCV'),
        ('numpy', 'NumPy'),
        ('requests', 'Requests')
    ]
    
    passed = 0
    
    # Test Python dependencies
    for module, name in dependencies:
        try:
            __import__(module)
            log_success(f"{name}")
            passed += 1
        except ImportError:
            log_error(f"{name}: Not installed")
    
    # Test Node.js availability for frontend applications
    import subprocess
    try:
        result = subprocess.run(['node', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            log_success(f"Node.js: {result.stdout.strip()}")
            passed += 1
        else:
            log_error("Node.js: Not available")
    except FileNotFoundError:
        log_error("Node.js: Not installed")
    
    try:
        result = subprocess.run(['npm', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            log_success(f"npm: {result.stdout.strip()}")
            passed += 1
        else:
            log_error("npm: Not available")
    except FileNotFoundError:
        log_error("npm: Not installed")
    
    return passed, len(dependencies) + 2  # +2 for Node.js and npm

def test_model_files():
    """Test model file access"""
    print(f"\n{Colors.PURPLE}🤖 Testing Model Files...{Colors.NC}")
    
    # Use new production path
    model_base = str(Path.home() / ".huddle-node-manager" / "bundled_models")
    
    # Check if the production directory exists
    if not os.path.exists(model_base):
        log_error(f"Production models directory not found: {model_base}")
        return 0, 0
    
    log_success(f"✓ Production models directory exists: {model_base}")
    
    # Model directories to check
    model_dirs = [
        ('llama-3.2-3b-quantized-q4km', 'Language Model'),
        ('whisper', 'Speech Recognition'),
        ('NeuroKit', 'Medical Analysis'),
        ('florence-2-large', 'Vision-Language Model'),
        ('surya-ocr', 'OCR Model'),
        ('metricgan-plus-voicebank', 'Audio Enhancement'),
        ('sepformer-dns4-16k-enhancement', 'Speech Enhancement'),
        ('paraphrase-multilingual-MiniLM-L12-v2', 'Multilingual Transformer'),
        ('xlm-roberta-language-detection', 'Language Detection')
    ]
    
    # Model files to check
    model_files = [
        ('yoloe_11l.pt', 'YOLO Object Detection'),
        ('yoloe-11l-seg.pt', 'YOLO Segmentation'),
        ('RealESRGAN_x4plus.pth', 'Image Super-Resolution')
    ]
    
    passed = 0
    total = len(model_dirs) + len(model_files)
    
    # Check model directories
    for dir_name, description in model_dirs:
        dir_path = os.path.join(model_base, dir_name)
        if os.path.exists(dir_path) and os.path.isdir(dir_path):
            log_success(f"✅ {description}")
            passed += 1
        else:
            log_warning(f"⚠️  {description}: Not found")
    
    # Check model files
    for file_name, description in model_files:
        file_path = os.path.join(model_base, file_name)
        if os.path.exists(file_path) and os.path.isfile(file_path):
            log_success(f"✅ {description}")
            passed += 1
        else:
            log_warning(f"⚠️  {description}: Not found")
    
    return passed, total

def test_configuration_files():
    """Test configuration file access"""
    print(f"\n{Colors.PURPLE}🔧 Testing Configuration Files...{Colors.NC}")
    
    # Check config files in production location
    config_files = [
        (str(Path.home() / ".huddle-node-manager" / "bundled_models" / "llama-3.2-3b-quantized-q4km" / "model_config.json"), 'GGUF Config (Production)'),
        ('device_config.json', 'Device Config')  # In root directory
    ]
    
    passed = 0
    for file_path, description in config_files:
        # Use absolute path since config files can be in different locations
        if check_file_access(file_path, description):
            passed += 1
    
    return passed, len(config_files)

def test_model_loading(quick_test=True):
    """Test actual model loading (optional)"""
    if not quick_test:
        print(f"\n{Colors.PURPLE}🚀 Testing Model Loading...{Colors.NC}")
        
        # Test GGUF loading
        try:
            from llama_cpp import Llama
            gguf_path = str(Path.home() / ".huddle-node-manager" / "bundled_models" / "llama-3.2-3b-quantized-q4km" / "llama-3.2-3b-instruct-q4_k_m.gguf")
            
            if os.path.exists(gguf_path):
                log_step("Loading GGUF model (this may take 10-15 seconds)...")
                start_time = time.time()
                
                llm = Llama(
                    model_path=gguf_path,
                    n_ctx=256,  # Small context for testing
                    n_threads=4,
                    verbose=False
                )
                load_time = time.time() - start_time
                log_success(f"GGUF model loaded in {load_time:.2f}s")
                
                # Quick inference test
                response = llm('Hello', max_tokens=10, stop=['\n'])
                log_success("GGUF inference working")
                return True
            else:
                log_warning("GGUF model not found for loading test")
                return False
                
        except Exception as e:
            log_error(f"GGUF model loading failed: {e}")
            return False
    else:
        log_info("Skipping model loading test (use --full for complete test)")
        return True

def main():
    """Main verification function"""
    print(f"{Colors.CYAN}🔍 Huddle Node Manager - Installation Verification{Colors.NC}")
    print("=" * 60)
    
    # Check if we're in the right directory (look for key files instead of api directory)
    if not os.path.exists('setup_dependencies.py') and not os.path.exists('install-hnm.sh'):
        log_error("Please run this from the huddle-node-manager root directory")
        return False
    
    log_info(f"Working directory: {os.getcwd()}")
    
    # Run tests
    results = {}
    
    # 1. Dependencies
    dep_passed, dep_total = test_dependencies()
    results['dependencies'] = (dep_passed, dep_total)
    
    # 2. Bundled models (NEW: Check production installation)
    bundled_passed = check_bundled_models()
    results['bundled_models'] = (1 if bundled_passed else 0, 1)
    
    # 3. Model files (legacy check)
    model_passed, model_total = test_model_files()
    results['model_files'] = (model_passed, model_total)
    
    # 4. Configuration files
    config_passed, config_total = test_configuration_files()
    results['config_files'] = (config_passed, config_total)
    
    # 5. Model loading (optional)
    full_test = '--full' in sys.argv or '--complete' in sys.argv
    loading_success = test_model_loading(quick_test=not full_test)
    results['model_loading'] = (1 if loading_success else 0, 1)
    
    # Summary
    print(f"\n{Colors.PURPLE}📊 Verification Summary{Colors.NC}")
    print("=" * 30)
    
    total_passed = 0
    total_tests = 0
    
    for test_name, (passed, total) in results.items():
        total_passed += passed
        total_tests += total
        percentage = (passed / total * 100) if total > 0 else 0
        
        if percentage == 100:
            status = f"{Colors.GREEN}✅"
        elif percentage >= 80:
            status = f"{Colors.YELLOW}⚠️"
        else:
            status = f"{Colors.RED}❌"
        
        print(f"{status} {test_name.replace('_', ' ').title()}: {passed}/{total} ({percentage:.1f}%){Colors.NC}")
    
    overall_percentage = (total_passed / total_tests * 100) if total_tests > 0 else 0
    
    print(f"\n{Colors.CYAN}🎯 Overall Score: {total_passed}/{total_tests} ({overall_percentage:.1f}%){Colors.NC}")
    
    if overall_percentage >= 90:
        print(f"{Colors.GREEN}🎉 Excellent! Your installation is working perfectly.{Colors.NC}")
        success = True
    elif overall_percentage >= 70:
        print(f"{Colors.YELLOW}⚠️ Good! Minor issues detected but core functionality should work.{Colors.NC}")
        success = True
    else:
        print(f"{Colors.RED}❌ Issues detected. Some components may not work properly.{Colors.NC}")
        success = False
    
    print(f"\n{Colors.BLUE}💡 Tips:{Colors.NC}")
    print("  • Run 'python test_dependencies.py' for quick dependency check")
    print("  • Run 'python verify_installation.py --full' for complete model loading test")
    print("  • Check documentation in docs/ for troubleshooting")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 