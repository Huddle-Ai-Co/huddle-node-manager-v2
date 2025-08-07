#!/usr/bin/env python3
"""
Huddle Node Manager - macOS System Dependencies Installer
Automatically installs Homebrew and required system packages for macOS
"""

import os
import sys
import platform
import subprocess
import shutil
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

def run_command(cmd, description="", ignore_errors=False):
    """Run a shell command and return success status"""
    try:
        log_step(f"{description}...")
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            log_success(f"{description} completed")
            return True
        else:
            if ignore_errors:
                log_warning(f"{description} failed (ignored): {result.stderr.strip()}")
                return False
            else:
                log_error(f"{description} failed: {result.stderr.strip()}")
                return False
    except Exception as e:
        log_error(f"{description} error: {e}")
        return False

def check_macos():
    """Verify this is running on macOS"""
    if platform.system() != 'Darwin':
        log_error("This script is designed for macOS only")
        return False
    
    log_info(f"Detected macOS {platform.mac_ver()[0]}")
    return True

def check_command_exists(command):
    """Check if a command exists in PATH"""
    return shutil.which(command) is not None

def check_homebrew():
    """Check if Homebrew is installed"""
    if check_command_exists('brew'):
        log_success("Homebrew is installed")
        return True
    else:
        log_warning("Homebrew not found")
        return False

def install_homebrew():
    """Install Homebrew package manager"""
    log_step("Installing Homebrew...")
    
    # Official Homebrew installation command
    install_cmd = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    
    print(f"{Colors.YELLOW}")
    print("🍺 Installing Homebrew...")
    print("This may take several minutes and will prompt for your password.")
    print("Homebrew is essential for installing system dependencies on macOS.")
    print(f"{Colors.NC}")
    
    try:
        # Run interactively so user can see prompts
        result = subprocess.run(install_cmd, shell=True)
        
        if result.returncode == 0:
            log_success("Homebrew installed successfully")
            
            # Add Homebrew to PATH for current session
            homebrew_paths = [
                "/opt/homebrew/bin",  # Apple Silicon
                "/usr/local/bin"      # Intel Mac
            ]
            
            for brew_path in homebrew_paths:
                if os.path.exists(brew_path) and brew_path not in os.environ['PATH']:
                    os.environ['PATH'] = f"{brew_path}:{os.environ['PATH']}"
                    log_info(f"Added {brew_path} to PATH")
            
            return True
        else:
            log_error("Homebrew installation failed")
            return False
            
    except Exception as e:
        log_error(f"Homebrew installation error: {e}")
        return False

def check_xcode_tools():
    """Check if Xcode Command Line Tools are installed"""
    try:
        result = subprocess.run(['xcode-select', '-p'], capture_output=True, text=True)
        if result.returncode == 0:
            log_success("Xcode Command Line Tools are installed")
            return True
        else:
            log_warning("Xcode Command Line Tools not found")
            return False
    except FileNotFoundError:
        log_warning("Xcode Command Line Tools not found")
        return False

def install_xcode_tools():
    """Install Xcode Command Line Tools"""
    log_step("Installing Xcode Command Line Tools...")
    
    print(f"{Colors.YELLOW}")
    print("🔨 Installing Xcode Command Line Tools...")
    print("A dialog will appear asking you to install the tools.")
    print("Please click 'Install' and wait for completion.")
    print(f"{Colors.NC}")
    
    try:
        subprocess.run(['xcode-select', '--install'], check=False)
        
        print(f"{Colors.CYAN}")
        print("Please wait for the Xcode Command Line Tools installation to complete,")
        print("then press Enter to continue...")
        print(f"{Colors.NC}")
        input()
        
        return check_xcode_tools()
    except Exception as e:
        log_error(f"Xcode tools installation error: {e}")
        return False

def install_system_packages():
    """Install required system packages via Homebrew"""
    
    # Core system packages needed for our dependencies
    packages = {
        'cmake': 'CMake - Required for building llama-cpp-python with Metal',
        'git': 'Git - Version control and repository cloning',
        'python@3.11': 'Python 3.11 - Modern Python interpreter',
        'portaudio': 'PortAudio - Required for pyaudio (audio I/O)',
        'ffmpeg': 'FFmpeg - Audio/video processing for ffmpeg-python',
        'tesseract': 'Tesseract - OCR engine for pytesseract',
        'pkg-config': 'pkg-config - Helps find installed libraries',
        'openssl': 'OpenSSL - Cryptography support',
        'libjpeg': 'JPEG library - Image processing support',
        'libpng': 'PNG library - Image processing support',
        'zlib': 'zlib - Compression library',
        'sentencepiece': 'SentencePiece - Required for sentencepiece Python package',
        'coreutils': 'Coreutils - Provides nproc and other GNU utilities',
        'azure-cli': 'Azure CLI - Cloud management and deployment tools',
        
        # Scientific computing packages available via Homebrew
        'numpy': 'NumPy - Scientific computing library (system version)',
        'scipy': 'SciPy - Scientific computing library (system version)',
        'opencv': 'OpenCV - Computer vision library (system version)',
        'pytorch': 'PyTorch - Deep learning framework (system version)'
    }
    
    log_info(f"Installing {len(packages)} system packages...")
    
    # Update Homebrew first
    if not run_command('brew update', 'Updating Homebrew', ignore_errors=True):
        log_warning("Could not update Homebrew, continuing anyway...")
    
    success_count = 0
    for package, description in packages.items():
        log_step(f"Installing {package} ({description})")
        
        # Check if already installed
        check_cmd = f'brew list {package}'
        if run_command(check_cmd, f"Checking if {package} is installed", ignore_errors=True):
            log_success(f"{package} already installed")
            success_count += 1
            continue
        
        # Install the package
        install_cmd = f'brew install {package}'
        if run_command(install_cmd, f"Installing {package}", ignore_errors=True):
            success_count += 1
        else:
            log_warning(f"Failed to install {package}, continuing...")
    
    log_info(f"System packages: {success_count}/{len(packages)} installed successfully")
    return success_count >= len(packages) * 0.8  # 80% success rate is acceptable

def verify_installation():
    """Verify that key tools are now available"""
    log_step("Verifying installation...")
    
    required_tools = {
        'brew': 'Homebrew package manager',
        'cmake': 'CMake build system',
        'git': 'Git version control',
        'python3': 'Python 3 interpreter',
        'pip3': 'Python package installer',
        'tesseract': 'Tesseract OCR engine',
        'ffmpeg': 'FFmpeg media processor'
    }
    
    verified_count = 0
    for tool, description in required_tools.items():
        if check_command_exists(tool):
            log_success(f"{tool} - {description}")
            verified_count += 1
        else:
            log_warning(f"{tool} - {description} (not found)")
    
    log_info(f"Tools verified: {verified_count}/{len(required_tools)}")
    return verified_count >= len(required_tools) * 0.8

def create_environment_setup():
    """Create environment setup script for proper PATH configuration"""
    
    setup_script = """#!/bin/bash
# macOS Environment Setup for Huddle Node Manager
# Add this to your ~/.zshrc or ~/.bash_profile

# Homebrew PATH (Apple Silicon)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Homebrew PATH (Intel Mac)  
if [[ -d "/usr/local/bin" ]]; then
    export PATH="/usr/local/bin:$PATH"
fi

# Python 3.11 from Homebrew
if [[ -d "/opt/homebrew/opt/python@3.11/bin" ]]; then
    export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"
elif [[ -d "/usr/local/opt/python@3.11/bin" ]]; then
    export PATH="/usr/local/opt/python@3.11/bin:$PATH"
fi

# PKG_CONFIG_PATH for native libraries
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# OpenSSL configuration for cryptography packages
export LDFLAGS="-L/opt/homebrew/opt/openssl/lib -L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/opt/homebrew/opt/openssl/include -I/usr/local/opt/openssl/include"

echo "✅ macOS environment configured for Huddle Node Manager"
"""
    
    try:
        with open('macos_environment_setup.sh', 'w') as f:
            f.write(setup_script)
        
        os.chmod('macos_environment_setup.sh', 0o755)
        log_success("Created macos_environment_setup.sh")
        return True
    except Exception as e:
        log_error(f"Failed to create environment setup: {e}")
        return False

def main():
    """Main installation function"""
    print(f"{Colors.CYAN}🍎 Huddle Node Manager - macOS System Dependencies{Colors.NC}")
    print("=" * 60)
    
    # 1. Verify macOS
    if not check_macos():
        return False
    
    # 2. Check/Install Xcode Command Line Tools
    if not check_xcode_tools():
        if not install_xcode_tools():
            log_error("Xcode Command Line Tools are required. Please install manually.")
            return False
    
    # 3. Check/Install Homebrew
    if not check_homebrew():
        if not install_homebrew():
            log_error("Homebrew installation failed")
            return False
    
    # 4. Install system packages
    if not install_system_packages():
        log_warning("Some system packages failed to install")
    
    # 5. Verify installation
    verified = verify_installation()
    
    # 6. Create environment setup
    create_environment_setup()
    
    # Summary
    print(f"\n{Colors.PURPLE}📋 macOS Setup Summary{Colors.NC}")
    print("=" * 30)
    
    if verified:
        log_success("🎉 macOS system dependencies installed successfully!")
        print(f"\n{Colors.CYAN}🚀 Next Steps:{Colors.NC}")
        print("  1. Restart your terminal (to pick up new PATH)")
        print("  2. Run: source macos_environment_setup.sh")
        print("  3. Run: python3 setup_dependencies.py")
        print("  4. Run: python3 verify_installation.py")
        
        print(f"\n{Colors.BLUE}💡 Optional:{Colors.NC}")
        print("  • Add to ~/.zshrc: source /path/to/macos_environment_setup.sh")
        print("  • This ensures proper environment in future terminal sessions")
        
    else:
        log_warning("⚠️ Some components may not work properly")
        print(f"\n{Colors.BLUE}🔧 Manual Installation:{Colors.NC}")
        print("  • Install missing tools manually using: brew install <package>")
        print("  • Ensure Xcode Command Line Tools are installed")
    
    return verified

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("macOS System Dependencies Installer for Huddle Node Manager")
        print("\nUsage:")
        print("  python3 setup_macos_dependencies.py")
        print("\nThis script will:")
        print("  • Install Xcode Command Line Tools (if needed)")
        print("  • Install Homebrew package manager (if needed)")
        print("  • Install required system packages (CMake, FFmpeg, etc.)")
        print("  • Create environment configuration script")
        sys.exit(0)
    
    success = main()
    sys.exit(0 if success else 1) 