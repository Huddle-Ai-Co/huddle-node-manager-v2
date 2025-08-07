#!/usr/bin/env python3
"""
Complete Fast Model Downloader - Downloads all AI models including HuggingFace, direct downloads, and local models
"""

import os
import sys
import subprocess
import shutil
import urllib.request
import zipfile
from pathlib import Path
from typing import Dict, List

class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
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
    print(f"{Colors.BLUE}🔄 {msg}{Colors.NC}")

class CompleteFastModelDownloader:
    def __init__(self):
        # PRODUCTION INSTALLATION: Use unique directory to prevent conflicts
        # This creates a clean installation separate from project files
        self.bundled_models_dir = Path.home() / ".huddle-node-manager" / "bundled_models"
        
        # Ensure the directory exists
        self.bundled_models_dir.mkdir(parents=True, exist_ok=True)
        
        self.hf_cache_dir = self.bundled_models_dir / ".cache"
        
        # Add version tracking for production
        self.version_file = self.bundled_models_dir / ".model_versions.json"
        self.model_versions = self._load_model_versions()
        
        # HuggingFace models
        self.hf_models = {
            "llama-3.2-3b-quantized-q4km": {
                "repo_id": "hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF",
                "filename": "llama-3.2-3b-instruct-q4_k_m.gguf",
                "description": "Large language model (GGUF format)",
                "size_estimate": "~2GB",
                "config_needed": True,
                "version": "1.0.0"
            },
            "metricgan-plus-voicebank": {
                "repo_id": "speechbrain/metricgan-plus-voicebank",
                "description": "Audio enhancement model",
                "size_estimate": "~500MB",
                "version": "1.0.0"
            },
            "sepformer-dns4-16k-enhancement": {
                "repo_id": "speechbrain/sepformer-dns4-16k-enhancement", 
                "description": "Speech enhancement model",
                "size_estimate": "~800MB",
                "version": "1.0.0"
            },
            "whisper": {
                "repo_id": "openai/whisper-base",
                "description": "Speech recognition model",
                "size_estimate": "~1GB",
                "version": "1.0.0"
            },
            "paraphrase-multilingual-MiniLM-L12-v2": {
                "repo_id": "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
                "description": "Multilingual sentence transformer (50+ languages)",
                "size_estimate": "~470MB",
                "version": "1.0.0"
            },
            "xlm-roberta-language-detection": {
                "repo_id": "papluca/xlm-roberta-base-language-detection",
                "description": "Multilingual language detection model",
                "size_estimate": "~1.1GB",
                "version": "1.0.0"
            },
            "florence-2-large": {
                "repo_id": "microsoft/Florence-2-large",
                "description": "Microsoft's advanced vision-language model with OCR",
                "size_estimate": "~1.5GB",
                "version": "1.0.0"
            },
            "surya-ocr": {
                "repo_id": "vikp/surya_rec",
                "description": "High-performance modern OCR recognition model",
                "size_estimate": "~524MB",
                "version": "1.0.0"
            }
        }
        
        # Direct download models
        self.direct_models = {
            "yoloe_11l.pt": {
                "url": "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11l.pt",
                "description": "YOLO object detection model",
                "size_estimate": "~50MB",
                "version": "8.3.0"
            },
            "yoloe-11l-seg.pt": {
                "url": "https://github.com/ultralytics/assets/releases/download/v8.3.0/yoloe-11l-seg.pt",
                "description": "YOLO segmentation model",
                "size_estimate": "~50MB",
                "version": "8.3.0"
            },
            "RealESRGAN_x4plus.pth": {
                "url": "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth",
                "description": "Image super-resolution model",
                "size_estimate": "~100MB",
                "version": "0.1.0"
            }
        }
        
        # Local models that need ZIP download and setup.py installation
        self.local_models = {
            "NeuroKit": {
                "zip_url": "https://github.com/neuropsychology/NeuroKit/archive/refs/heads/master.zip",
                "description": "Advanced ECG processing and HRV analysis",
                "setup_needed": True,
                "size_estimate": "~50MB",
                "version": "master"
            }
        }
    
    def _load_model_versions(self) -> dict:
        """Load existing model versions from file"""
        if self.version_file.exists():
            try:
                import json
                with open(self.version_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                log_warning(f"Could not load model versions: {e}")
        return {}
    
    def _save_model_versions(self):
        """Save current model versions to file"""
        try:
            import json
            self.version_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.version_file, 'w') as f:
                json.dump(self.model_versions, f, indent=2)
        except Exception as e:
            log_warning(f"Could not save model versions: {e}")
    
    def _check_model_version(self, model_name: str, expected_version: str) -> bool:
        """Check if model exists and is the correct version"""
        if model_name in self.model_versions:
            current_version = self.model_versions[model_name]
            if current_version == expected_version:
                log_info(f"✓ {model_name} (v{current_version}) already exists and is current")
                return True
            else:
                log_warning(f"⚠️ {model_name} version mismatch: current={current_version}, expected={expected_version}")
                return False
        return False
    
    def _update_model_version(self, model_name: str, version: str):
        """Update model version in tracking"""
        self.model_versions[model_name] = version
        self._save_model_versions()
    
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
        
        return True
    
    def create_directories(self):
        """Create necessary directories"""
        log_step("Creating directory structure...")
        
        self.bundled_models_dir.mkdir(parents=True, exist_ok=True)
        self.hf_cache_dir.mkdir(parents=True, exist_ok=True)
        log_success("Directories created")
    
    def download_hf_model(self, model_name: str, config: Dict) -> bool:
        """Download a HuggingFace model with optimized settings"""
        log_step(f"Downloading {model_name} ({config['description']})...")
        print(f"  Estimated size: {config['size_estimate']}")
        
        model_dir = self.bundled_models_dir / model_name
        
        # Skip if already exists and is the correct version
        if self._check_model_version(model_name, config["version"]):
            return True
        
        # Skip if already exists
        if model_dir.exists() and any(model_dir.iterdir()):
            log_info(f"✓ {model_name} already exists, skipping")
            return True
        
        try:
            # Use optimized download settings
            if config.get("filename"):
                # Download specific file
                cmd = [
                    "huggingface-cli", "download",
                    config["repo_id"],
                    config["filename"],
                    "--local-dir", str(model_dir),
                    "--cache-dir", str(self.hf_cache_dir),
                    "--resume-download",
                    "--quiet"
                ]
            else:
                # Download full repository
                cmd = [
                    "huggingface-cli", "download",
                    config["repo_id"],
                    "--local-dir", str(model_dir),
                    "--cache-dir", str(self.hf_cache_dir),
                    "--resume-download",
                    "--quiet"
                ]
            
            log_info(f"Starting download...")
            print(f"  This may take several minutes for large models...")
            
            # Use timeout to prevent hanging
            result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=1800)
            
            log_success(f"Downloaded {model_name}")
            
            # Handle model config file for llama models
            if model_name == "llama-3.2-3b-quantized-q4km":
                self._setup_llama_config(model_dir)
            
            # Update version tracking
            self._update_model_version(model_name, config["version"])
            
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
    
    def _setup_llama_config(self, model_dir: Path):
        """Setup model config file for llama model"""
        log_step("Setting up Llama model configuration...")
        
        # Source config file
        config_source = Path("model_config.json")
        config_target = model_dir / "model_config.json"
        
        # Remove any existing config in target directory
        if config_target.exists():
            log_info("Removing existing model_config.json from target directory")
            config_target.unlink()
        
        # Move config file to model directory
        if config_source.exists():
            try:
                import shutil
                shutil.move(str(config_source), str(config_target))
                log_success("✓ Moved model_config.json to llama directory")
                
                # Remove any duplicate config from root (shouldn't exist but safety)
                root_config = Path("model_config.json")
                if root_config.exists():
                    log_info("Removing duplicate model_config.json from root")
                    root_config.unlink()
                    
            except Exception as e:
                log_error(f"Failed to move model config: {e}")
        else:
            log_warning("model_config.json not found in current directory")
    
    def download_direct_model(self, model_name: str, config: Dict) -> bool:
        """Download a model directly from URL"""
        log_step(f"Downloading {model_name} ({config['description']})...")
        print(f"  Estimated size: {config['size_estimate']}")
        
        model_path = self.bundled_models_dir / model_name
        
        # Skip if already exists and is the correct version
        if self._check_model_version(model_name, config["version"]):
            return True
        
        # Skip if already exists
        if model_path.exists():
            log_info(f"✓ {model_name} already exists, skipping")
            return True
        
        try:
            log_info(f"Starting download from {config['url']}...")
            
            with urllib.request.urlopen(config["url"]) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                
                with open(model_path, 'wb') as f:
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
            log_success(f"Downloaded {model_name} ({downloaded / 1024 / 1024:.1f}MB)")
            
            # Update version tracking
            self._update_model_version(model_name, config["version"])
            
            return True
            
        except Exception as e:
            log_error(f"Failed to download {model_name}: {e}")
            if model_path.exists():
                model_path.unlink()
            return False
    
    def download_local_model(self, model_name: str, config: Dict) -> bool:
        """Download and setup a local model using ZIP download"""
        log_step(f"Downloading {model_name} ({config['description']})...")
        print(f"  Estimated size: {config['size_estimate']}")
        
        # Special handling for NeuroKit using dedicated script
        if model_name.lower() == "neurokit":
            return self._setup_neurokit_specialized()
        
        model_dir = self.bundled_models_dir / model_name
        
        # Skip if already exists and is the correct version
        if self._check_model_version(model_name, config["version"]):
            return True
        
        # Skip if already exists
        if model_dir.exists() and any(model_dir.iterdir()):
            log_info(f"✓ {model_name} already exists, skipping")
            return True
        
        # Remove existing directory
        if model_dir.exists():
            log_info("Removing existing directory...")
            shutil.rmtree(model_dir)
        
        # Download ZIP file
        log_info("Downloading ZIP file (faster than git clone)...")
        zip_path = self.bundled_models_dir / f"{model_name}.zip"
        
        try:
            with urllib.request.urlopen(config["zip_url"]) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                
                with open(zip_path, 'wb') as f:
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
            log_success(f"Downloaded {model_name} ZIP ({downloaded / 1024 / 1024:.1f}MB)")
            
        except Exception as e:
            log_error(f"Failed to download {model_name}: {e}")
            return False
        
        # Extract ZIP file
        log_step("Extracting...")
        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.bundled_models_dir)
            
            # Rename extracted directory
            extracted_dir = self.bundled_models_dir / f"{model_name}-master"
            if extracted_dir.exists():
                extracted_dir.rename(model_dir)
            
            # Clean up ZIP file
            zip_path.unlink()
            
            log_success("Extracted successfully")
            
        except Exception as e:
            log_error(f"Failed to extract {model_name}: {e}")
            if zip_path.exists():
                zip_path.unlink()
            return False
        
        # Install from setup.py if needed
        if config.get("setup_needed"):
            log_step("Installing from setup.py...")
            original_cwd = os.getcwd()
            try:
                # Change to model directory
                os.chdir(model_dir)
                
                # Install in development mode
                subprocess.run([
                    sys.executable, "-m", "pip", "install", "-e", "."
                ], check=True, capture_output=True)
                
                log_success("Installed successfully")
                
            except subprocess.CalledProcessError as e:
                log_error(f"Failed to install {model_name}: {e.stderr.decode()}")
                return False
            except Exception as e:
                log_error(f"Error installing {model_name}: {e}")
                return False
            finally:
                # Always return to original directory
                os.chdir(original_cwd)
        
        # Update version tracking
        self._update_model_version(model_name, config["version"])
        
        return True
    
    def _setup_neurokit_specialized(self) -> bool:
        """Use the dedicated NeuroKit setup script"""
        log_step("Using specialized NeuroKit setup...")
        
        try:
            # Import and run the fast neurokit setup
            from fast_neurokit_setup import setup_neurokit_fast
            
            # Run the specialized setup (uses production path automatically)
            success = setup_neurokit_fast()
            
            if success:
                log_success("NeuroKit installed successfully using specialized setup")
                return True
            else:
                log_warning("Specialized NeuroKit setup failed - this may be due to temporary network issues")
                log_info("You can manually run: python fast_neurokit_setup.py to retry")
                return False
                
        except ImportError:
            log_warning("fast_neurokit_setup.py not found, using standard method")
            return False
        except Exception as e:
            log_warning(f"Error in specialized NeuroKit setup: {e}")
            log_info("This is likely a temporary network issue. You can retry manually later.")
            return False
    
    def download_all_models(self) -> bool:
        """Download all models with optimizations"""
        log_step("Starting complete model downloads...")
        
        success_count = 0
        total_models = len(self.hf_models) + len(self.direct_models) + len(self.local_models)
        
        # Download HuggingFace models
        log_info("Downloading HuggingFace models...")
        for model_name, config in self.hf_models.items():
            if self.download_hf_model(model_name, config):
                success_count += 1
            else:
                log_warning(f"Failed to download {model_name}, continuing...")
        
        # Download direct models
        log_info("Downloading direct models...")
        for model_name, config in self.direct_models.items():
            if self.download_direct_model(model_name, config):
                success_count += 1
            else:
                log_warning(f"Failed to download {model_name}, continuing...")
        
        # Download local models
        log_info("Downloading local models...")
        for model_name, config in self.local_models.items():
            if self.download_local_model(model_name, config):
                success_count += 1
            else:
                log_warning(f"Failed to download {model_name}, continuing...")
        
        success_rate = (success_count / total_models * 100) if total_models > 0 else 100
        log_info(f"Model downloads: {success_count}/{total_models} ({success_rate:.1f}%)")
        
        # Optimize cache after successful downloads
        if success_rate >= 80:
            self._optimize_cache()
        
        return success_rate >= 80
    
    def _optimize_cache(self):
        """Create comprehensive model index for all models with dynamic paths"""
        log_step("Creating comprehensive model index...")
        
        try:
            # Create model index directory
            index_dir = self.bundled_models_dir / ".cache" / "model_index"
            index_dir.mkdir(parents=True, exist_ok=True)
            
            log_info("Creating comprehensive model index...")
            
            # Index ALL models (HuggingFace, Direct, Local)
            all_models = {}
            all_models.update(self.hf_models)
            all_models.update(self.direct_models)
            all_models.update(self.local_models)
            
            indexed_count = 0
            for model_name, config in all_models.items():
                model_path = self.bundled_models_dir / model_name
                
                if model_path.exists():
                    # Create index entry for ALL models
                    index_entry = index_dir / f"{model_name}.index"
                    try:
                        import json
                        import platform
                        import os
                        
                        # Get dynamic system info
                        system_info = {
                            "platform": platform.system(),
                            "platform_release": platform.release(),
                            "architecture": platform.machine(),
                            "python_version": platform.python_version(),
                            "user_home": str(Path.home()),
                            "current_working_dir": str(Path.cwd()),
                            "bundled_models_dir": str(self.bundled_models_dir.absolute())
                        }
                        
                        # Determine model type and create appropriate index data
                        if model_name in self.hf_models:
                            model_type = "huggingface"
                            # Check if it's a directory or file
                            if model_path.is_dir():
                                size_bytes = sum(f.stat().st_size for f in model_path.rglob('*') if f.is_file())
                            else:
                                size_bytes = model_path.stat().st_size
                        elif model_name in self.direct_models:
                            model_type = "direct_download"
                            size_bytes = model_path.stat().st_size
                        else:  # local models
                            model_type = "local_install"
                            size_bytes = sum(f.stat().st_size for f in model_path.rglob('*') if f.is_file())
                        
                        index_data = {
                            "model_name": model_name,
                            "path": str(model_path.absolute()),
                            "relative_path": str(model_path.relative_to(self.bundled_models_dir)),
                            "size_bytes": size_bytes,
                            "size_mb": round(size_bytes / 1024 / 1024, 2),
                            "type": model_type,
                            "system_info": system_info,
                            "indexed_at": str(Path.cwd()),
                            "indexed_timestamp": str(Path().cwd().stat().st_mtime)
                        }
                        
                        # Add model-specific metadata
                        if model_name in self.hf_models:
                            index_data["hf_repo_id"] = config.get("repo_id", "")
                            index_data["hf_filename"] = config.get("filename", "")
                        elif model_name in self.direct_models:
                            index_data["download_url"] = config.get("url", "")
                        elif model_name in self.local_models:
                            index_data["setup_needed"] = config.get("setup_needed", False)
                            index_data["zip_url"] = config.get("zip_url", "")
                        
                        with open(index_entry, 'w') as f:
                            json.dump(index_data, f, indent=2)
                        indexed_count += 1
                        
                    except Exception as e:
                        log_warning(f"Could not create index entry for {model_name}: {e}")
            
            log_success(f"✓ Comprehensive model index complete: {indexed_count} models indexed")
            log_info(f"  - All models indexed with dynamic paths")
            log_info(f"  - System info captured for cross-device compatibility")
            log_info(f"  - Relative and absolute paths included")
            
        except Exception as e:
            log_warning(f"Model indexing failed: {e}")
            log_info("Models will still work, just may need path lookup")
    
    def verify_downloads(self) -> bool:
        """Verify that all models were downloaded correctly"""
        log_step("Verifying downloads...")
        
        success = True
        
        # Check HuggingFace models
        for model_name in self.hf_models:
            model_dir = self.bundled_models_dir / model_name
            if model_dir.exists() and any(model_dir.iterdir()):
                log_success(f"✓ {model_name}")
            else:
                log_error(f"✗ {model_name} missing or empty")
                success = False
        
        # Check direct models
        for model_name in self.direct_models:
            model_path = self.bundled_models_dir / model_name
            if model_path.exists():
                log_success(f"✓ {model_name}")
            else:
                log_error(f"✗ {model_name} missing")
                success = False
        
        # Check local models
        for model_name in self.local_models:
            model_dir = self.bundled_models_dir / model_name
            if model_dir.exists() and any(model_dir.iterdir()):
                log_success(f"✓ {model_name}")
            else:
                log_error(f"✗ {model_name} missing or empty")
                success = False
        
        return success
    
    def test_imports(self) -> bool:
        """Test importing the downloaded models"""
        log_step("Testing model imports...")
        
        success = True
        
        # Test NeuroKit import
        try:
            # First try importing directly (if installed via pip)
            import neurokit2
            log_success("✓ NeuroKit import successful")
        except ImportError:
            # If direct import fails, try from the bundled directory
            try:
                neurokit_path = self.bundled_models_dir / "NeuroKit"
                if neurokit_path.exists():
                    sys.path.insert(0, str(neurokit_path))
                    import neurokit2
                    log_success("✓ NeuroKit import successful (from bundled directory)")
                else:
                    log_warning("⚠️ NeuroKit directory not found - may have failed to download")
                    log_info("You can manually run: python fast_neurokit_setup.py to retry")
                    success = False
            except ImportError as e:
                log_warning(f"⚠️ NeuroKit import failed: {e}")
                log_info("This is likely due to a temporary network issue during download")
                log_info("You can manually run: python fast_neurokit_setup.py to retry")
                success = False
        
        return success

def main():
    print(f"{Colors.BLUE}🚀 Complete Fast Model Downloader{Colors.NC}")
    print("=" * 55)
    
    downloader = CompleteFastModelDownloader()
    
    # Check dependencies
    if not downloader.check_dependencies():
        return False
    
    # Create directories
    downloader.create_directories()
    
    # Download models
    success = downloader.download_all_models()
    
    # Verify downloads
    if success:
        downloader.verify_downloads()
        downloader.test_imports()
        log_success("🎉 All model downloads completed!")
    else:
        log_warning("⚠️ Some model downloads failed")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 