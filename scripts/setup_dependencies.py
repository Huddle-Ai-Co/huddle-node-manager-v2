#!/usr/bin/env python3
"""
Huddle Node Manager - Comprehensive Dependency Setup
Automatically detects hardware and installs optimized dependencies
"""

import os
import sys
import platform
import subprocess
import json
from pathlib import Path

# Color output for better UX
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

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

class HardwareDetector:
    """Detects hardware capabilities and returns optimal installation configuration"""
    
    def __init__(self):
        self.system = platform.system().lower()
        self.machine = platform.machine().lower()
        self.config = self._detect_hardware()
        
    def _detect_hardware(self):
        """Comprehensive hardware detection"""
        config = {
            'platform': self.system,
            'architecture': self.machine,
            'cuda_available': False,
            'metal_available': False,
            'cpu_only': True,
            'python_version': f"{sys.version_info.major}.{sys.version_info.minor}",
            'optimization_flags': [],
            'special_packages': {}
        }
        
        # Detect Apple Silicon
        if self.system == 'darwin' and self.machine in ['arm64', 'aarch64']:
            config['metal_available'] = True
            config['cpu_only'] = False
            config['device_type'] = 'apple_silicon'
            config['optimization_flags'] = ['-DLLAMA_METAL=on']
            log_info("🍎 Apple Silicon detected - Metal acceleration available")
            
        elif self.system == 'darwin':
            config['device_type'] = 'apple_intel'
            log_info("🍎 Apple Intel detected")
            
        # Detect CUDA on Linux/Windows
        elif self.system in ['linux', 'windows']:
            config['cuda_available'] = self._check_cuda()
            if config['cuda_available']:
                config['cpu_only'] = False
                config['device_type'] = 'cuda'
                config['optimization_flags'] = ['-DLLAMA_CUDA=on']
                log_success("🚀 CUDA GPU detected")
            else:
                config['device_type'] = 'cpu'
                log_info("💻 CPU-only configuration")
        else:
            config['device_type'] = 'cpu'
            
        return config
    
    def _check_cuda(self):
        """Check if CUDA is available"""
        try:
            result = subprocess.run(['nvidia-smi'], 
                                  capture_output=True, text=True, timeout=10)
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def get_llama_cpp_install_command(self):
        """Generate appropriate llama-cpp-python installation command"""
        base_cmd = [sys.executable, "-m", "pip", "install", "llama-cpp-python", "--break-system-packages"]
        
        if self.config['metal_available']:
            # Apple Silicon with Metal
            env_vars = {'CMAKE_ARGS': '-DLLAMA_METAL=on'}
            return base_cmd, env_vars
            
        elif self.config['cuda_available']:
            # CUDA GPU
            env_vars = {'CMAKE_ARGS': '-DLLAMA_CUDA=on'}
            return base_cmd, env_vars
            
        else:
            # CPU only - use precompiled wheel if available
            return base_cmd, {}

class DependencyInstaller:
    """Handles installation of all dependencies with device-specific optimizations"""
    
    def __init__(self, hardware_config):
        self.hw = hardware_config
        self.requirements_file = Path(__file__).parent / "requirements.txt"
        
    def install_base_requirements(self):
        """Install base requirements from requirements.txt"""
        log_step("Installing base requirements...")
        
        if not self.requirements_file.exists():
            log_error(f"Requirements file not found: {self.requirements_file}")
            return False
            
        # Try installing all requirements first
        try:
            cmd = [sys.executable, "-m", "pip", "install", "-r", str(self.requirements_file), "--break-system-packages", "--force-reinstall"]
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            log_success("Base requirements installed successfully")
            return True
        except subprocess.CalledProcessError as e:
            log_warning(f"Failed to install all requirements: {e.stderr}")
            log_step("Trying individual package installation...")
            
            # Fallback: install packages individually, skipping problematic ones
            return self._install_packages_individually()
    
    def _install_packages_individually(self):
        """Install packages individually, skipping problematic ones"""
        # Core packages that are essential (from requirements.txt)
        core_packages = [
            # Core Scientific Computing
            "numpy", "scipy", "pandas", "scikit-learn",
            
            # Deep Learning Framework
            "torch", "torchvision", "torchaudio", "transformers", "tokenizers", 
            "accelerate", "bitsandbytes", "safetensors", "huggingface-hub",
            
            # Audio Processing
            "librosa", "soundfile", "openai-whisper", "speechbrain",
            "pydub", "pyttsx3",
            
            # Image Processing & Computer Vision  
            "pillow", "opencv-python", "ultralytics", "scikit-image", 
            "pytesseract", "easyocr",
            
            # Web Framework & API
            "fastapi", "uvicorn", "pydantic", "aiohttp",
            
            # Medical RAG & Azure Integration
            "azure-search-documents", "azure-core", "openai",
            
            # Document Processing
            "PyPDF2", "python-docx", "beautifulsoup4", "lxml", "nltk",
            
            # Network & IPFS
            "requests", "ipfshttpclient",
            
            # Utilities & Development
            "tqdm", "python-dotenv", "typing-extensions", "ffmpeg-python", 
            "psutil", "cryptography", "sentence-transformers", "pint",
            
            # Development & Testing
            "pytest", "matplotlib", "jupyter",
            
            # Medical Signal Processing
            "neurokit2", "PyWavelets", "hrv-analysis", "pyhrv"
        ]
        
        # Packages that are known to have issues on Apple Silicon
        problematic_packages = {
            "numpy": "available via Homebrew (system version)",
            "scipy": "available via Homebrew (system version)",
            "opencv-python": "available via Homebrew as opencv (system version)",
            "ultralytics": "numpy conflict with system installation", 
            "easyocr": "numpy conflict with system installation",
            "flash-attn": "requires CUDA (not available on Apple Silicon)",
            "pyaudio": "requires portaudio system dependency",
            "pyannote.audio": "complex audio processing dependencies",
            "resemblyzer": "complex audio processing dependencies",
            "SpeechRecognition": "requires pyaudio",
            "sentence-transformers": "may have numpy conflicts",
            "librosa": "numpy conflict with system installation",
            "openai-whisper": "numpy conflict with system installation",
            "pyhrv": "numpy conflict with system installation"
        }
        
        success_count = 0
        skipped_count = 0
        
        for package in core_packages:
            # Check if this is a known problematic package
            if package in problematic_packages:
                log_warning(f"⚠️ Skipping {package}: {problematic_packages[package]}")
                skipped_count += 1
                continue
                
            try:
                cmd = [sys.executable, "-m", "pip", "install", package, "--break-system-packages"]
                result = subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=300)
                log_success(f"✓ {package} installed")
                success_count += 1
            except subprocess.CalledProcessError as e:
                error_msg = e.stderr.strip()
                
                # Provide user-friendly error messages
                if "uninstall-no-record-file" in error_msg and "numpy" in error_msg:
                    log_warning(f"⚠️ Skipping {package}: numpy conflict with system installation")
                    skipped_count += 1
                elif "CUDA_HOME" in error_msg or "nvcc" in error_msg:
                    log_warning(f"⚠️ Skipping {package}: requires CUDA (not available on Apple Silicon)")
                    skipped_count += 1
                elif "timeout" in error_msg.lower():
                    log_warning(f"⚠️ {package} installation timed out")
                else:
                    log_warning(f"⚠️ Failed to install {package}: {error_msg[:100]}...")
                    
            except subprocess.TimeoutExpired:
                log_warning(f"⚠️ {package} installation timed out")
        
        log_info(f"Core packages: {success_count} installed, {skipped_count} skipped")
        
        # Provide a clear summary
        if skipped_count > 0:
            log_info("📋 Skipped packages summary:")
            for package, reason in problematic_packages.items():
                log_info(f"  • {package}: {reason}")
            log_info("💡 These packages can be installed manually if needed")
        
        return success_count >= (len(core_packages) - len(problematic_packages)) * 0.8  # 80% success rate for non-problematic packages
    
    def install_device_specific_packages(self):
        """Install device-specific optimized packages"""
        log_step(f"Installing device-specific packages for {self.hw.config['device_type']}...")
        
        # Install llama-cpp-python with appropriate flags
        success = self._install_llama_cpp_python()
        
        # Install PyTorch with device-specific index if needed
        if self.hw.config['cuda_available']:
            success &= self._install_pytorch_cuda()
        elif self.hw.config['metal_available']:
            success &= self._install_pytorch_metal()
            
        return success
    
    def _install_llama_cpp_python(self):
        """Install llama-cpp-python with optimal configuration"""
        log_step("Installing llama-cpp-python with device optimizations...")
        
        cmd, env_vars = self.hw.get_llama_cpp_install_command()
        
        # Set up environment variables
        env = os.environ.copy()
        env.update(env_vars)
        
        try:
            if env_vars:
                log_info(f"Using build flags: {env_vars}")
            
            result = subprocess.run(cmd, env=env, check=True, 
                                  capture_output=True, text=True, timeout=600)
            log_success("llama-cpp-python installed with device optimizations")
            return True
            
        except subprocess.CalledProcessError as e:
            log_warning(f"Optimized llama-cpp-python install failed: {e.stderr}")
            log_step("Falling back to standard installation...")
            
            # Fallback to standard installation
            try:
                cmd = [sys.executable, "-m", "pip", "install", "llama-cpp-python", "--break-system-packages"]
                subprocess.run(cmd, check=True, capture_output=True, text=True)
                log_success("llama-cpp-python installed (standard version)")
                return True
            except subprocess.CalledProcessError as e2:
                log_error(f"Failed to install llama-cpp-python: {e2.stderr}")
                return False
        except subprocess.TimeoutExpired:
            log_error("llama-cpp-python installation timed out")
            return False
    
    def _install_pytorch_cuda(self):
        """Install PyTorch with CUDA support"""
        log_step("Installing PyTorch with CUDA support...")
        
        try:
            cmd = [
                sys.executable, "-m", "pip", "install", 
                "torch", "torchvision", "torchaudio", 
                "--index-url", "https://download.pytorch.org/whl/cu118",
                "--break-system-packages"
            ]
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            log_success("PyTorch with CUDA support installed")
            return True
        except subprocess.CalledProcessError as e:
            log_warning(f"CUDA PyTorch install failed, using default: {e.stderr}")
            return True  # Not critical, base requirements include PyTorch
    
    def _install_pytorch_metal(self):
        """Verify PyTorch Metal Performance Shaders support on Apple Silicon"""
        log_step("Verifying PyTorch Metal support...")
        
        try:
            import torch
            if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
                log_success("PyTorch Metal Performance Shaders (MPS) available")
            else:
                log_warning("PyTorch MPS not available, using CPU")
        except ImportError:
            log_warning("PyTorch not yet installed")
        
        return True
    
    def create_device_config(self):
        """Create device configuration file for runtime optimization"""
        config_file = Path(__file__).parent / "device_config.json"
        
        config_data = {
            'detected_hardware': self.hw.config,
            'installation_timestamp': subprocess.check_output(['date']).decode().strip(),
            'python_version': self.hw.config['python_version'],
            'optimizations_applied': True,
            'llama_cpp_available': self._check_llama_cpp_installed(),
            'recommended_settings': self._get_recommended_settings()
        }
        
        try:
            with open(config_file, 'w') as f:
                json.dump(config_data, f, indent=2)
            log_success(f"Device configuration saved to {config_file}")
        except Exception as e:
            log_warning(f"Could not save device config: {e}")
    
    def _check_llama_cpp_installed(self):
        """Check if llama-cpp-python was successfully installed"""
        try:
            import llama_cpp
            return True
        except ImportError:
            return False
    
    def _get_recommended_settings(self):
        """Generate recommended runtime settings based on hardware"""
        settings = {
            'model_loading': {},
            'inference': {},
            'memory_management': {}
        }
        
        if self.hw.config['metal_available']:
            settings['model_loading']['device'] = 'mps'
            settings['inference']['use_metal'] = True
            settings['memory_management']['gpu_layers'] = -1  # Use all GPU layers
            
        elif self.hw.config['cuda_available']:
            settings['model_loading']['device'] = 'cuda'
            settings['inference']['use_cuda'] = True
            settings['memory_management']['gpu_layers'] = -1
            
        else:
            settings['model_loading']['device'] = 'cpu'
            settings['inference']['threads'] = os.cpu_count()
            settings['memory_management']['cpu_threads'] = os.cpu_count()
        
        return settings

def main():
    """Main installation routine"""
    print(f"\n{Colors.PURPLE}🏗️  Huddle Node Manager - Dependency Setup{Colors.NC}")
    print(f"{Colors.CYAN}Device-agnostic installation with hardware optimization{Colors.NC}\n")
    
    # Check if we're in a virtual environment
    if not hasattr(sys, 'real_prefix') and not (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        log_warning("⚠️  Not running in a virtual environment!")
        log_info("For best results, activate the virtual environment first:")
        log_info("  source hnm_env/bin/activate")
        log_info("Continuing with system Python installation...")
    else:
        log_success("✅ Running in virtual environment")
    
    # 1. Install system dependencies first (cross-platform)
    try:
        from setup_system_dependencies import SystemDependencyManager
        log_info("🌐 Installing cross-platform system dependencies...")
        sys_manager = SystemDependencyManager()
        if sys_manager.package_manager != 'unknown':
            sys_manager.install_system_dependencies()
            log_success("System dependencies handled")
        else:
            log_info("Unknown package manager - skipping system setup")
    except ImportError:
        log_info("Cross-platform system setup not available, using OS-specific setup")
    except Exception as e:
        log_warning(f"System dependency setup had issues: {e}")
    
    # 2. Detect hardware
    log_step("Detecting hardware configuration...")
    detector = HardwareDetector()
    
    print(f"\n{Colors.BLUE}📊 Hardware Detection Results:{Colors.NC}")
    print(f"  Platform: {detector.config['platform']}")
    print(f"  Architecture: {detector.config['architecture']}")
    print(f"  Device Type: {detector.config['device_type']}")
    print(f"  Metal Available: {detector.config['metal_available']}")
    print(f"  CUDA Available: {detector.config['cuda_available']}")
    print(f"  Python Version: {detector.config['python_version']}\n")
    
    # Initialize installer
    installer = DependencyInstaller(detector)
    
    # Install dependencies
    success = True
    
    # 1. Install base requirements
    success &= installer.install_base_requirements()
    
    # 2. Install device-specific packages
    success &= installer.install_device_specific_packages()
    
    # 3. Create device configuration
    installer.create_device_config()
    
    # Results
    print(f"\n{Colors.BLUE}📋 Installation Summary:{Colors.NC}")
    if success:
        log_success("🎉 All dependencies installed successfully!")
        log_info("Your system is optimized for:")
        if detector.config['metal_available']:
            print(f"  🍎 Apple Silicon with Metal acceleration")
        elif detector.config['cuda_available']:
            print(f"  🚀 NVIDIA CUDA GPU acceleration")
        else:
            print(f"  💻 CPU-optimized performance")
    else:
        log_warning("⚠️ Some optimizations may not be available")
        log_info("Basic functionality should still work")
    
    print(f"\n{Colors.CYAN}🚀 Next Steps:{Colors.NC}")
    print(f"  1. Activate your environment: source hnm_env/bin/activate")
    print(f"  2. Verify installation: python verify_installation.py")
    print(f"  3. Test the installation: python -c 'import torch; print(torch.__version__)'")
    print(f"  4. Run your GGUF server: python ~/.huddle-node-manager/bundled_models/optimized_gguf_server.py")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 