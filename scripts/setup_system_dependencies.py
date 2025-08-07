#!/usr/bin/env python3
"""
Huddle Node Manager - Cross-Platform System Dependencies
Automatically detects OS and installs required system packages
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
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return True
        else:
            if not ignore_errors:
                log_error(f"{description} failed: {result.stderr.strip()}")
            return False
    except Exception as e:
        if not ignore_errors:
            log_error(f"{description} error: {e}")
        return False

def check_command_exists(command):
    """Check if a command exists in PATH"""
    return shutil.which(command) is not None

class SystemDependencyManager:
    """Cross-platform system dependency management"""
    
    def __init__(self):
        self.system = platform.system().lower()
        self.distro = self._detect_linux_distro() if self.system == 'linux' else None
        self.package_manager = self._detect_package_manager()
        
        # Common system dependencies needed by our Python packages and Node.js applications
        self.dependencies = {
            'cmake': 'CMake build system (for llama-cpp-python)',
            'git': 'Git version control',
            'python3': 'Python 3 interpreter',
            'pip': 'Python package installer',
            'nodejs': 'Node.js runtime (for Next.js/Electron apps)',
            'npm': 'Node Package Manager (for frontend dependencies)',
            'portaudio': 'Audio I/O library (for pyaudio)',
            'ffmpeg': 'Media processing (for ffmpeg-python)',
            'tesseract': 'OCR engine (for pytesseract)',
            'openssl': 'Cryptography support',
            'pkg-config': 'Library configuration helper',
            'azure-cli': 'Azure CLI for cloud management and deployment'
        }
    
    def _detect_linux_distro(self):
        """Detect Linux distribution"""
        try:
            import distro
            return distro.id()
        except ImportError:
            # Fallback detection
            if os.path.exists('/etc/debian_version'):
                return 'debian'
            elif os.path.exists('/etc/redhat-release'):
                return 'rhel'
            elif os.path.exists('/etc/arch-release'):
                return 'arch'
            else:
                return 'unknown'
    
    def _detect_package_manager(self):
        """Detect available package manager"""
        if self.system == 'darwin':
            if check_command_exists('brew'):
                return 'homebrew'
            else:
                return 'homebrew_needed'
                
        elif self.system == 'linux':
            if check_command_exists('apt') or check_command_exists('apt-get'):
                return 'apt'
            elif check_command_exists('yum'):
                return 'yum'
            elif check_command_exists('dnf'):
                return 'dnf'
            elif check_command_exists('pacman'):
                return 'pacman'
            elif check_command_exists('zypper'):
                return 'zypper'
            else:
                return 'unknown'
                
        elif self.system == 'windows':
            if check_command_exists('choco'):
                return 'chocolatey'
            elif check_command_exists('winget'):
                return 'winget'
            else:
                return 'chocolatey_needed'
        
        return 'unknown'
    
    def get_package_mapping(self):
        """Get OS-specific package names"""
        mappings = {
            'homebrew': {
                'cmake': 'cmake',
                'git': 'git', 
                'python3': 'python@3.11',
                'pip': None,  # Included with Python
                'nodejs': 'node',
                'npm': None,  # Included with Node.js
                'portaudio': 'portaudio',
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract',
                'openssl': 'openssl',
                'pkg-config': 'pkg-config',
                'azure-cli': 'azure-cli'
            },
            'apt': {
                'cmake': 'cmake',
                'git': 'git',
                'python3': 'python3 python3-pip python3-dev',
                'pip': 'python3-pip',
                'nodejs': 'nodejs npm',
                'npm': 'npm',
                'portaudio': 'portaudio19-dev',
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract-ocr',
                'openssl': 'libssl-dev',
                'pkg-config': 'pkg-config',
                'azure-cli': 'azure-cli'
            },
            'yum': {
                'cmake': 'cmake',
                'git': 'git',
                'python3': 'python3 python3-pip python3-devel',
                'pip': 'python3-pip',
                'nodejs': 'nodejs npm',
                'npm': 'npm',
                'portaudio': 'portaudio-devel',
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract',
                'openssl': 'openssl-devel',
                'pkg-config': 'pkgconfig',
                'azure-cli': 'azure-cli'
            },
            'dnf': {
                'cmake': 'cmake',
                'git': 'git',
                'python3': 'python3 python3-pip python3-devel',
                'pip': 'python3-pip',
                'nodejs': 'nodejs npm',
                'npm': 'npm',
                'portaudio': 'portaudio-devel',
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract',
                'openssl': 'openssl-devel',
                'pkg-config': 'pkgconfig',
                'azure-cli': 'azure-cli'
            },
            'pacman': {
                'cmake': 'cmake',
                'git': 'git',
                'python3': 'python python-pip',
                'pip': 'python-pip',
                'nodejs': 'nodejs npm',
                'npm': 'npm',
                'portaudio': 'portaudio',
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract',
                'openssl': 'openssl',
                'pkg-config': 'pkgconf',
                'azure-cli': 'azure-cli'
            },
            'chocolatey': {
                'cmake': 'cmake',
                'git': 'git',
                'python3': 'python3',
                'pip': None,  # Included with Python
                'nodejs': 'nodejs',
                'npm': None,  # Included with Node.js
                'portaudio': None,  # Windows specific handling
                'ffmpeg': 'ffmpeg',
                'tesseract': 'tesseract',
                'openssl': 'openssl',
                'pkg-config': None,
                'azure-cli': 'azure-cli'
            },
            'winget': {
                'cmake': 'Kitware.CMake',
                'git': 'Git.Git',
                'python3': 'Python.Python.3.11',
                'pip': None,
                'nodejs': 'OpenJS.NodeJS',
                'npm': None,  # Included with Node.js
                'portaudio': None,
                'ffmpeg': 'Gyan.FFmpeg',
                'tesseract': 'UB-Mannheim.TesseractOCR',
                'openssl': None,
                'pkg-config': None,
                'azure-cli': 'Microsoft.AzureCLI'
            }
        }
        
        return mappings.get(self.package_manager, {})
    
    def check_package_installed(self, package_name):
        """Check if a package is already installed"""
        if self.package_manager == 'homebrew':
            return run_command(f'brew list {package_name}', ignore_errors=True)
        elif self.package_manager == 'apt':
            return run_command(f'dpkg -l | grep -q "^ii  {package_name}"', ignore_errors=True)
        elif self.package_manager in ['yum', 'dnf']:
            return run_command(f'{self.package_manager} list installed {package_name}', ignore_errors=True)
        elif self.package_manager == 'pacman':
            return run_command(f'pacman -Q {package_name}', ignore_errors=True)
        elif self.package_manager == 'chocolatey':
            return run_command(f'choco list --local-only | grep -q "{package_name}"', ignore_errors=True)
        elif self.package_manager == 'winget':
            return run_command(f'winget list | grep -q "{package_name}"', ignore_errors=True)
        else:
            # Fallback: check if command exists
            return check_command_exists(package_name)
    
    def install_package_manager(self):
        """Install package manager if needed"""
        if self.package_manager == 'homebrew_needed':
            log_step("Installing Homebrew...")
            cmd = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            if run_command(cmd, "Installing Homebrew"):
                self.package_manager = 'homebrew'
                # Update PATH
                homebrew_paths = ["/opt/homebrew/bin", "/usr/local/bin"]
                for path in homebrew_paths:
                    if os.path.exists(path) and path not in os.environ['PATH']:
                        os.environ['PATH'] = f"{path}:{os.environ['PATH']}"
                return True
            return False
            
        elif self.package_manager == 'chocolatey_needed':
            log_step("Installing Chocolatey...")
            cmd = 'powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(\'https://chocolatey.org/install.ps1\'))"'
            if run_command(cmd, "Installing Chocolatey"):
                self.package_manager = 'chocolatey'
                return True
            return False
        
        return True  # Package manager already available
    
    def install_system_dependencies(self):
        """Install all required system dependencies"""
        log_info(f"🖥️  Detected: {self.system.title()} with {self.package_manager}")
        
        # Install package manager if needed
        if not self.install_package_manager():
            log_error("Failed to install package manager")
            return False
        
        # Get package mappings
        package_mapping = self.get_package_mapping()
        if not package_mapping:
            log_error(f"Unsupported package manager: {self.package_manager}")
            return False
        
        # Install packages
        success_count = 0
        total_packages = len([p for p in package_mapping.values() if p])
        
        for dep, description in self.dependencies.items():
            packages = package_mapping.get(dep)
            if not packages:
                log_info(f"⏭️  Skipping {dep} (not needed on this platform)")
                continue
            
            # Handle space-separated package lists
            package_list = packages.split() if isinstance(packages, str) else [packages]
            
            # Check if any variant is already installed
            installed = False
            for pkg in package_list:
                if self.check_package_installed(pkg):
                    log_success(f"{dep} already installed ({pkg})")
                    installed = True
                    success_count += 1
                    break
            
            if installed:
                continue
            
            # Install the package(s)
            log_step(f"Installing {dep}: {packages}")
            install_cmd = self._get_install_command(packages)
            
            if run_command(install_cmd, f"Installing {dep}"):
                log_success(f"{dep} installed successfully")
                success_count += 1
            else:
                log_warning(f"Failed to install {dep}")
        
        success_rate = (success_count / total_packages * 100) if total_packages > 0 else 100
        log_info(f"System dependencies: {success_count}/{total_packages} ({success_rate:.1f}%)")
        
        return success_rate >= 80
    
    def _get_install_command(self, packages):
        """Generate install command for package manager"""
        if self.package_manager == 'homebrew':
            return f'brew install {packages}'
        elif self.package_manager == 'apt':
            return f'sudo apt update && sudo apt install -y {packages}'
        elif self.package_manager in ['yum', 'dnf']:
            return f'sudo {self.package_manager} install -y {packages}'
        elif self.package_manager == 'pacman':
            return f'sudo pacman -S --noconfirm {packages}'
        elif self.package_manager == 'chocolatey':
            return f'choco install -y {packages}'
        elif self.package_manager == 'winget':
            return f'winget install {packages}'
        else:
            return f'echo "Unknown package manager: {self.package_manager}"'
    
    def create_environment_script(self):
        """Create platform-specific environment setup script"""
        if self.system == 'darwin':
            # Use the existing macOS setup script
            return True
        elif self.system == 'linux':
            script_content = """#!/bin/bash
# Linux Environment Setup for Huddle Node Manager

# Add common paths
export PATH="/usr/local/bin:$PATH"

# PKG_CONFIG_PATH for development libraries
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:$PKG_CONFIG_PATH"

# Python path
if [[ -d "/usr/local/bin" ]]; then
    export PATH="/usr/local/bin:$PATH"
fi

echo "✅ Linux environment configured for Huddle Node Manager"
"""
            filename = 'linux_environment_setup.sh'
        elif self.system == 'windows':
            script_content = """@echo off
REM Windows Environment Setup for Huddle Node Manager

REM Add common paths
set PATH=C:\\ProgramData\\chocolatey\\bin;%PATH%
set PATH=C:\\Users\\%USERNAME%\\AppData\\Local\\Microsoft\\WindowsApps;%PATH%

echo ✅ Windows environment configured for Huddle Node Manager
"""
            filename = 'windows_environment_setup.bat'
        else:
            return True
        
        try:
            with open(filename, 'w') as f:
                f.write(script_content)
            os.chmod(filename, 0o755)
            log_success(f"Created {filename}")
            return True
        except Exception as e:
            log_error(f"Failed to create environment script: {e}")
            return False

def main():
    """Main installation function"""
    print(f"{Colors.CYAN}🌐 Huddle Node Manager - Cross-Platform System Dependencies{Colors.NC}")
    print("=" * 70)
    
    manager = SystemDependencyManager()
    
    log_info(f"Platform: {manager.system.title()}")
    log_info(f"Package Manager: {manager.package_manager}")
    if manager.distro:
        log_info(f"Distribution: {manager.distro}")
    
    print(f"\n{Colors.PURPLE}📦 Installing System Dependencies...{Colors.NC}")
    
    success = manager.install_system_dependencies()
    
    print(f"\n{Colors.PURPLE}🔧 Creating Environment Setup...{Colors.NC}")
    manager.create_environment_script()
    
    # Summary
    print(f"\n{Colors.PURPLE}📋 Setup Summary{Colors.NC}")
    print("=" * 30)
    
    if success:
        log_success("🎉 System dependencies installed successfully!")
        print(f"\n{Colors.CYAN}🚀 Next Steps:{Colors.NC}")
        print("  1. Restart your terminal")
        print("  2. Run: python3 setup_dependencies.py")
        print("  3. Run: python3 verify_installation.py")
    else:
        log_warning("⚠️ Some dependencies may need manual installation")
        print(f"\n{Colors.BLUE}📖 Manual Installation Guides:{Colors.NC}")
        print("  • Check platform-specific documentation")
        print("  • Install missing packages manually")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 