#!/usr/bin/env python3
"""
HNM Bundled Models Setup
Downloads and configures all required models and components for HNM
"""

import os
import sys
import json
import subprocess
import shutil
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class Colors:
    PURPLE = '\033[0;35m'
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'

def log_info(message):
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.NC}")

def log_success(message):
    print(f"{Colors.GREEN}✅ {message}{Colors.NC}")

def log_warning(message):
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.NC}")

def log_error(message):
    print(f"{Colors.RED}❌ {message}{Colors.NC}")

def log_step(message):
    print(f"{Colors.BLUE}🔄 {message}{Colors.NC}")

class BundledModelsSetup:
    def __init__(self):
        # PRODUCTION INSTALLATION: Always use standardized user home location
        # This prevents conflicts with project files and ensures clean production deployment
        self.bundled_models_dir = Path.home() / ".huddle-node-manager" / "bundled_models"
        self.hf_cache_dir = self.bundled_models_dir / ".cache"
        
        # Ensure the directory exists
        self.bundled_models_dir.mkdir(parents=True, exist_ok=True)
        
        # Model configurations
        self.huggingface_models = {
            "llama-3.2-3b-quantized-q4km": {
                "repo_id": "hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF",
                "filename": "llama-3.2-3b-instruct-q4_k_m.gguf", 
                "config_needed": True
            },
            "metricgan-plus-voicebank": {
                "repo_id": "speechbrain/metricgan-plus-voicebank",
                "type": "full_repo",
                "use_fast_download": True,  # Use optimized download
                "description": "Audio enhancement model"
            },
            "sepformer-dns4-16k-enhancement": {
                "repo_id": "speechbrain/sepformer-dns4-16k-enhancement",
                "type": "full_repo",
                "use_fast_download": True,  # Use optimized download
                "description": "Speech enhancement model"
            },
            "whisper": {
                "repo_id": "openai/whisper-base",
                "type": "full_repo",
                "use_fast_download": True,  # Use optimized download
                "description": "Speech recognition model"
            },
            "xlm-roberta-language-detection": {
                "repo_id": "papluca/xlm-roberta-base-language-detection",
                "type": "full_repo",
                "use_fast_download": True,  # Use optimized download
                "description": "Multilingual language detection model - XLM-RoBERTa",
                "model_size": "~1.1GB",
                "languages_supported": "22+ languages including Arabic, Chinese, Japanese, etc.",
                "use_case": "OCR text language detection with 99%+ accuracy"
            },

            "florence-2-large": {
                "repo_id": "microsoft/Florence-2-large",
                "type": "full_repo", 
                "use_fast_download": True,
                "description": "Microsoft's advanced vision-language model with OCR",
                "model_size": "~1.5GB",
                "capabilities": "OCR, handwriting, document understanding, vision QA",
                "use_case": "State-of-the-art OCR + vision model, excellent for complex documents",
                "performance": "Can read doctor prescriptions and complex handwriting"
            },
            "surya-ocr": {
                "repo_id": "vikp/surya_rec", 
                "type": "full_repo",
                "use_fast_download": True,
                "description": "High-performance modern OCR recognition model",
                "model_size": "~524MB",
                "capabilities": "Advanced text recognition, multilingual support",
                "use_case": "Modern OCR alternative to Tesseract with better accuracy",
                "performance": "State-of-the-art text recognition performance"
            }
        }
        
        # Local bundled models that need setup.py installation
        self.local_models = {
            "NeuroKit": {
                "repo_url": "https://github.com/neuropsychology/NeuroKit.git",
                "zip_url": "https://github.com/neuropsychology/NeuroKit/archive/refs/heads/master.zip",
                "setup_needed": True,
                "description": "Advanced ECG processing and HRV analysis",
                "use_zip": True  # Use zip download instead of git clone for speed
            }
        }
        
        self.direct_downloads = {
            "yoloe-11l-seg.pt": "https://github.com/ultralytics/assets/releases/download/v8.3.0/yoloe-11l-seg.pt",
            "RealESRGAN_x4plus.pth": "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
        }

    def check_dependencies(self) -> bool:
        """Check if required dependencies are available"""
        log_step("Checking dependencies...")
        
        # Check for huggingface-cli
        if not shutil.which("huggingface-cli"):
            log_warning("huggingface-cli not found, installing...")
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", "huggingface_hub[cli]"], check=True)
                log_success("Installed huggingface_hub[cli]")
            except subprocess.CalledProcessError as e:
                log_error(f"Failed to install huggingface_hub: {e}")
                return False
        
        # Check for git (needed for some HF repos and local models)
        if not shutil.which("git"):
            log_warning("git not found - some model downloads may fail")
        
        # Install additional dependencies
        dependencies = [
            "transformers>=4.20.0",
            "torch",
            "torchvision",  # Required for vision models
            "tokenizers",  # Required by transformers for language detection
            "sentencepiece",  # Required by XLM-RoBERTa tokenizer
            "timm>=0.9.0",  # Required by Florence-2
            "flash-attn",  # For faster attention in transformers
            "einops",  # Required by vision transformers
            "pillow>=8.0.0",  # Image processing for OCR models
            "speechbrain",
            "ultralytics",
            "opencv-python",
            "PyWavelets>=1.8.0",  # Required by neurokit2
            "pytesseract",  # Keep as fallback OCR engine
            "easyocr",  # Alternative OCR engine
            "surya-ocr",  # Modern document OCR engine
            "clip",  # Required by YOLOE for text prompting
            "ftfy",  # Required by CLIP for text processing
            "wcwidth"  # Required by CLIP for text formatting
        ]
        
        for dep in dependencies:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", dep], 
                             check=True, capture_output=True)
                log_info(f"✓ {dep}")
            except subprocess.CalledProcessError:
                log_warning(f"Failed to install {dep} - may already be installed")
        
        return True

    def create_directories(self):
        """Create necessary directories"""
        log_step("Creating directory structure...")
        
        directories = [
            self.bundled_models_dir,
            self.hf_cache_dir,
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            log_info(f"✓ {directory}")

    def create_gitignore(self):
        """Create .gitignore for bundled_models"""
        gitignore_content = """# Large model files
*.pt
*.pth
*.gguf
*.bin
*.safetensors
*.h5

# Model directories
llama-3.2-3b-*/
metricgan-plus-voicebank/
sepformer-dns4-16k-enhancement/
whisper/
xlm-roberta-language-detection/
florence-2-large/
surya-ocr/

# Cache directories
.cache/
__pycache__/
*.pyc

# Temporary files
*.tmp
*.temp
.DS_Store
"""
        
        gitignore_path = self.bundled_models_dir / ".gitignore"
        with open(gitignore_path, "w") as f:
            f.write(gitignore_content)
        log_success("Created .gitignore")

    def download_huggingface_model(self, model_name: str, config: Dict) -> bool:
        """Download a model from Hugging Face"""
        log_step(f"Downloading {model_name} from Hugging Face...")
        
        model_dir = self.bundled_models_dir / model_name
        model_dir.mkdir(exist_ok=True)
        
        try:
            # Use optimized download if specified
            if config.get("use_fast_download"):
                log_info(f"Using optimized download for {model_name}...")
                cmd = [
                    "huggingface-cli", "download",
                    config["repo_id"],
                    "--local-dir", str(model_dir),
                    "--cache-dir", str(self.hf_cache_dir),
                    "--resume-download",  # Resume interrupted downloads
                    "--local-files-only", "false"  # Allow network download
                ]
            else:
                if config.get("type") == "full_repo":
                    # Download full repository
                    cmd = [
                        "huggingface-cli", "download",
                        config["repo_id"],
                        "--local-dir", str(model_dir),
                        "--cache-dir", str(self.hf_cache_dir)
                    ]
                else:
                    # Download specific file
                    cmd = [
                        "huggingface-cli", "download",
                        config["repo_id"],
                        config["filename"],
                        "--local-dir", str(model_dir),
                        "--cache-dir", str(self.hf_cache_dir)
                    ]
            
            log_info(f"Running: {' '.join(cmd)}")
            print(f"  This may take several minutes for large models...")
            
            # Use timeout to prevent hanging
            result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=1800)  # 30 minute timeout
            
            # Create model config if needed
            if config.get("config_needed"):
                self.create_model_config(model_name, config)
            
            log_success(f"Downloaded {model_name}")
            return True
            
        except subprocess.TimeoutExpired:
            log_error(f"Download timeout for {model_name} - model may be too large")
            return False
        except subprocess.CalledProcessError as e:
            log_error(f"Failed to download {model_name}: {e.stderr}")
            return False
        except Exception as e:
            log_error(f"Error downloading {model_name}: {e}")
            return False

    def create_model_config(self, model_name: str, config: Dict):
        """Create model configuration file"""
        model_dir = self.bundled_models_dir / model_name
        config_path = model_dir / "model_config.json"
        
        model_config = {
            "model_name": f"{model_name}-q4_k_m",
            "model_type": "gguf",
            "model_format": "GGUF",
            "quantization": "Q4_K_M",
            "description": f"{model_name} (Quantized)",
            "version": "1.0.0",
            "author": "Meta AI",
            "license": "Meta AI License",
            "source": config.get("repo_id", ""),
            "filename": config.get("filename", ""),
            "loading_config": {
                "n_ctx": 8192,
                "n_batch": 512,
                "n_threads": None,
                "n_gpu_layers": 1,
                "verbose": False,
                "use_mmap": True,
                "use_mlock": False,
                "f16_kv": True
            },
            "generation_config": {
                "max_tokens": 32000,
                "temperature": 0.7,
                "top_p": 0.9,
                "frequency_penalty": 0.0,
                "presence_penalty": 0.0,
                "repetition_penalty": 1.1,
                "stop_sequences": []
            },
            "model_info": {
                "parameters": "3.2B",
                "context_length": 8192,
                "vocab_size": 32000,
                "architecture": "LlamaForCausalLM",
                "quantization_method": "Q4_K_M",
                "file_size_gb": 1.9
            },
            "optimization_settings": {
                "platform_optimized": True,
                "memory_efficient": True,
                "gpu_accelerated": True,
                "recommended_device": "mps",
                "fallback_device": "cpu"
            },
            "compatibility": {
                "llama_cpp": True,
                "transformers": False,
                "torch": False,
                "supported_formats": ["gguf"]
            }
        }
        
        with open(config_path, "w") as f:
            json.dump(model_config, f, indent=2)
        log_success(f"Created config: {config_path}")

    def download_direct_file(self, filename: str, url: str) -> bool:
        """Download a file directly from URL"""
        log_step(f"Downloading {filename}...")
        
        filepath = self.bundled_models_dir / filename
        
        # Skip if already exists and is not empty
        if filepath.exists() and filepath.stat().st_size > 0:
            log_info(f"✓ {filename} already exists, skipping")
            return True
        
        try:
            with urllib.request.urlopen(url) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                
                with open(filepath, 'wb') as f:
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r  Progress: {percent:.1f}% ({downloaded / 1024 / 1024:.1f}MB)", end="")
                
                print()  # New line after progress
                log_success(f"Downloaded {filename} ({downloaded / 1024 / 1024:.1f}MB)")
                return True
                
        except Exception as e:
            log_error(f"Failed to download {filename}: {e}")
            if filepath.exists():
                filepath.unlink()  # Remove partial download
            return False

    def setup_local_model(self, model_name: str, config: Dict) -> bool:
        """Clone and setup a local model with setup.py installation"""
        log_step(f"Setting up {model_name} from {config['repo_url']}...")
        
        model_dir = self.bundled_models_dir / model_name
        
        # Skip if already exists and has setup.py
        if model_dir.exists() and (model_dir / "setup.py").exists():
            log_info(f"✓ {model_name} already exists, checking installation...")
            
            # Check if it's properly installed
            try:
                import sys
                sys.path.insert(0, str(self.bundled_models_dir))
                __import__(model_name.lower())
                log_success(f"{model_name} already installed and working")
                return True
            except ImportError:
                log_info(f"Reinstalling {model_name}...")
        
        # Download the repository (zip or git)
        try:
            if model_dir.exists():
                shutil.rmtree(model_dir)  # Remove existing directory
            
            # Use zip download if available and preferred
            if config.get("use_zip") and "zip_url" in config:
                log_step(f"Downloading {model_name} as ZIP (faster than git clone)...")
                print(f"  This should be faster than git cloning...")
                
                # Download zip file
                zip_path = self.bundled_models_dir / f"{model_name}.zip"
                try:
                    with urllib.request.urlopen(config["zip_url"]) as response:
                        with open(zip_path, 'wb') as f:
                            shutil.copyfileobj(response, f)
                    
                    # Extract zip file
                    import zipfile
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(self.bundled_models_dir)
                    
                    # Rename extracted directory to model_name
                    extracted_dir = self.bundled_models_dir / f"{model_name}-master"
                    if extracted_dir.exists():
                        extracted_dir.rename(model_dir)
                    
                    # Clean up zip file
                    zip_path.unlink()
                    
                    log_success(f"Downloaded and extracted {model_name}")
                    
                except Exception as e:
                    log_warning(f"Zip download failed: {e}, falling back to git clone...")
                    # Fall back to git clone
                    raise e
                    
            else:
                # Use git clone
                log_step(f"Cloning {model_name} repository (shallow clone for speed)...")
                print(f"  This may take a few minutes for large repositories...")
                
                # Use timeout to prevent hanging
                result = subprocess.run([
                    "git", "clone", "--depth", "1", "--single-branch", config["repo_url"], str(model_dir)
                ], check=True, capture_output=True, timeout=300)  # 5 minute timeout
                
                log_success(f"Cloned {model_name} repository")
            
        except subprocess.CalledProcessError as e:
            log_error(f"Failed to clone {model_name}: {e.stderr.decode()}")
            return False
        except Exception as e:
            log_error(f"Error cloning {model_name}: {e}")
            return False
        
        # Install from setup.py if needed
        if config.get("setup_needed"):
            log_step(f"Installing {model_name} from setup.py...")
            try:
                # Change to the model directory
                original_cwd = os.getcwd()
                os.chdir(model_dir)
                
                # Install in development mode
                subprocess.run([
                    sys.executable, "-m", "pip", "install", "-e", "."
                ], check=True, capture_output=True)
                
                # Return to original directory
                os.chdir(original_cwd)
                
                log_success(f"Installed {model_name} successfully")
                return True
                
            except subprocess.CalledProcessError as e:
                log_error(f"Failed to install {model_name}: {e.stderr.decode()}")
                os.chdir(original_cwd)  # Return to original directory
                return False
            except Exception as e:
                log_error(f"Error installing {model_name}: {e}")
                os.chdir(original_cwd)  # Return to original directory
                return False
        
        return True

    def setup_optimized_servers(self):
        """Ensure optimized server dependencies are installed"""
        log_step("Setting up optimized server dependencies...")
        
        server_dependencies = [
            "fastapi",
            "uvicorn",
            "pydantic",
            "llama-cpp-python",
            "gguf",
            "psutil",
            "GPUtil"
        ]
        
        for dep in server_dependencies:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", dep], 
                             check=True, capture_output=True)
                log_info(f"✓ {dep}")
            except subprocess.CalledProcessError:
                log_warning(f"Failed to install {dep}")

    def setup_model_servers(self):
        """Setup optimized model servers in the bundled_models directory"""
        log_step("Setting up model servers...")
        
        # Source directory for server files (current directory)
        source_dir = Path.cwd()
        log_info(f"Using source directory: {source_dir}")
        
        # Target directory (production path)
        target_dir = self.bundled_models_dir
        
        # Essential server files to copy
        server_files = [
            "optimized_gguf_server.py",
            "optimized_resource_server.py", 
            "platform_adaptive_config.py",
            "device_detection_test.py",
            "resource_monitor.py",
            "vllm_style_optimizer.py"
        ]
        
        copied_count = 0
        for file_name in server_files:
            source_file = source_dir / file_name
            target_file = target_dir / file_name
            
            if source_file.exists():
                try:
                    import shutil
                    shutil.copy2(source_file, target_file)
                    log_success(f"✓ {file_name}")
                    copied_count += 1
                except Exception as e:
                    log_warning(f"⚠️ Failed to copy {file_name}: {e}")
            else:
                log_warning(f"⚠️ {file_name} not found in source")
        
        log_info(f"Copied {copied_count}/{len(server_files)} essential server files")
        
        # Generate platform configuration
        self.generate_platform_config()

    def setup_service_directories(self):
        """Setup service directories for new production structure"""
        log_step("Setting up service directories...")
        
        # In the new production structure, we don't need the old service directories
        # All models are stored in the bundled_models directory
        log_info("Using new production structure - service directories not needed")
        log_success("✓ Service directories setup complete")

    def generate_platform_config(self):
        """Generate platform-specific configuration"""
        log_step("Generating platform configuration...")
        
        try:
            # Import and use platform_adaptive_config.py
            import sys
            sys.path.insert(0, str(Path.cwd()))
            
            from platform_adaptive_config import PlatformAdaptiveConfig
            
            config = PlatformAdaptiveConfig()
            config_path = self.bundled_models_dir / "platform_config.json"
            config.save_config(str(config_path))
            
            log_success(f"✓ Generated platform config: {config_path}")
        except Exception as e:
            log_warning(f"Failed to generate platform config: {e}")
            # Create a basic config as fallback
            basic_config = {
                "platform": "unknown",
                "device": "auto",
                "optimization_strategy": "default"
            }
            config_path = self.bundled_models_dir / "platform_config.json"
            with open(config_path, 'w') as f:
                json.dump(basic_config, f, indent=2)
            log_info(f"✓ Created basic platform config: {config_path}")

    def verify_installation(self) -> bool:
        """Verify that all models and components are properly installed"""
        log_step("Verifying installation...")
        
        success = True
        
        # Define model locations (production only)
        model_locations = [
            self.bundled_models_dir,  # Production location (user home)
        ]
        
        # Check HuggingFace models
        for model_name in self.huggingface_models:
            found = False
            for location in model_locations:
                model_dir = location / model_name
                if model_dir.exists() and any(model_dir.iterdir()):
                    log_success(f"✓ {model_name}")
                    found = True
                    break
            if not found:
                log_error(f"✗ {model_name} missing or empty")
                success = False
        
        # Check direct downloads
        for filename in self.direct_downloads:
            found = False
            for location in model_locations:
                filepath = location / filename
                if filepath.exists() and filepath.stat().st_size > 0:
                    size_mb = filepath.stat().st_size / 1024 / 1024
                    log_success(f"✓ {filename} ({size_mb:.1f}MB)")
                    found = True
                    break
            if not found:
                log_error(f"✗ {filename} missing or empty")
                success = False
        
        # Check local models
        for model_name in self.local_models:
            found = False
            for location in model_locations:
                model_dir = location / model_name
                if model_dir.exists() and (model_dir / "setup.py").exists():
                    try:
                        # Test the actual installed package, not the directory
                        # Handle special case for NeuroKit (module is neurokit2, not neurokit)
                        if model_name.lower() == "neurokit":
                            import neurokit2
                        else:
                            __import__(model_name.lower())
                        log_success(f"✓ {model_name} installed and working")
                        found = True
                        break
                    except ImportError as e:
                        continue  # Try next location
            if not found:
                log_error(f"✗ {model_name} not properly installed")
                success = False
        
        # Check critical files for model execution
        critical_files = [
            self.bundled_models_dir / "optimized_gguf_server.py",
            self.bundled_models_dir / "optimized_resource_server.py",
            self.bundled_models_dir / "platform_adaptive_config.py",
            self.bundled_models_dir / "device_detection_test.py",
            self.bundled_models_dir / "resource_monitor.py",
            self.bundled_models_dir / "platform_config.json",
            self.bundled_models_dir / ".gitignore"
        ]
        
        for filepath in critical_files:
            if filepath.exists():
                log_success(f"✓ {filepath.name}")
            else:
                log_warning(f"⚠ {filepath.name} missing")
        
        return success

    def run_setup(self, skip_large_models: bool = False) -> bool:
        """Run the complete setup process"""
        print(f"{Colors.PURPLE}🤖 HNM Bundled Models Setup{Colors.NC}")
        print(f"{Colors.BLUE}Setting up AI models and components...{Colors.NC}")
        print()
        
        # Check dependencies
        if not self.check_dependencies():
            return False
        
        # Create directories
        self.create_directories()
        
        # Create .gitignore
        self.create_gitignore()
        
        # Use the comprehensive fast model downloader
        if not skip_large_models:
            log_step("Using comprehensive fast model downloader...")
            try:
                # Import and run the complete downloader
                from fast_model_downloader_complete import CompleteFastModelDownloader
                downloader = CompleteFastModelDownloader()
                
                # Check dependencies and create directories
                if not downloader.check_dependencies():
                    log_warning("Fast downloader dependencies failed, falling back to manual download")
                    # Fallback to original method
                    for model_name, config in self.huggingface_models.items():
                        if not self.download_huggingface_model(model_name, config):
                            log_warning(f"Failed to download {model_name}, continuing...")
                    
                    for filename, url in self.direct_downloads.items():
                        if not self.download_direct_file(filename, url):
                            log_warning(f"Failed to download {filename}, continuing...")
                    
                    for model_name, config in self.local_models.items():
                        if not self.setup_local_model(model_name, config):
                            log_warning(f"Failed to setup {model_name}, continuing...")
                else:
                    downloader.create_directories()
                    if downloader.download_all_models():
                        log_success("✅ All models downloaded successfully via fast downloader")
                    else:
                        log_warning("Fast downloader had issues, some models may be missing")
                        
            except ImportError as e:
                log_warning(f"Fast downloader not available: {e}, using manual download")
                # Fallback to original method
                for model_name, config in self.huggingface_models.items():
                    if not self.download_huggingface_model(model_name, config):
                        log_warning(f"Failed to download {model_name}, continuing...")
                
                for filename, url in self.direct_downloads.items():
                    if not self.download_direct_file(filename, url):
                        log_warning(f"Failed to download {filename}, continuing...")
                
                for model_name, config in self.local_models.items():
                    if not self.setup_local_model(model_name, config):
                        log_warning(f"Failed to setup {model_name}, continuing...")
        else:
            log_info("Skipping large model downloads (use --download-models to include)")
        
        # Setup server dependencies
        self.setup_optimized_servers()
        
        # Copy essential model server files
        self.setup_model_servers()
        
        # Setup service directories
        self.setup_service_directories()
        
        # Generate platform configuration
        self.generate_platform_config()
        
        # Verify installation
        success = self.verify_installation()
        
        if success:
            log_success("🎉 Bundled models setup completed successfully!")
        else:
            log_warning("⚠️ Setup completed with some issues")
        
        return success

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Setup HNM bundled models and components")
    parser.add_argument("--skip-large-models", action="store_true", 
                       help="Skip downloading large models (for minimal installation)")
    parser.add_argument("--download-models", action="store_true",
                       help="Download all models including large ones")
    
    args = parser.parse_args()
    
    setup = BundledModelsSetup()
    
    # Default behavior - ask user about large models
    skip_large = args.skip_large_models
    if not args.download_models and not args.skip_large_models:
        print(f"{Colors.YELLOW}📦 Model Download Options:{Colors.NC}")
        print("  1) Download all models (~2-5GB) - Complete functionality")
        print("  2) Skip large models (~50MB) - Basic functionality only")
        print()
        
        choice = input("Choose option (1-2) [1]: ").strip() or "1"
        skip_large = (choice == "2")
    
    success = setup.run_setup(skip_large_models=skip_large)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 