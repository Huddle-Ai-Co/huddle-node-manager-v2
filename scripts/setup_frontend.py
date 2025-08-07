#!/usr/bin/env python3
"""
Huddle Node Manager - Frontend Dependencies Setup
Installs Node.js dependencies for Next.js and Electron applications
"""

import os
import sys
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

def check_command_exists(command):
    """Check if a command exists in PATH"""
    return shutil.which(command) is not None

def run_command(cmd, description="", cwd=None):
    """Run a shell command and return success status"""
    try:
        log_step(f"{description}...")
        result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
        
        if result.returncode == 0:
            log_success(f"{description} completed")
            return True
        else:
            log_error(f"{description} failed: {result.stderr.strip()}")
            return False
    except Exception as e:
        log_error(f"{description} error: {e}")
        return False

def check_node_requirements():
    """Check if Node.js and npm are available"""
    log_step("Checking Node.js environment...")
    
    if not check_command_exists('node'):
        log_error("Node.js not found. Please install Node.js first:")
        print("  • macOS: brew install node")
        print("  • Ubuntu: sudo apt install nodejs npm")
        print("  • Windows: choco install nodejs")
        return False
    
    if not check_command_exists('npm'):
        log_error("npm not found. Please install npm first")
        return False
    
    # Check Node.js version
    try:
        result = subprocess.run(['node', '--version'], capture_output=True, text=True)
        node_version = result.stdout.strip()
        log_success(f"Node.js version: {node_version}")
        
        # Extract major version number
        major_version = int(node_version.replace('v', '').split('.')[0])
        if major_version < 18:
            log_warning(f"Node.js {node_version} detected. Recommended: >= 18.0.0")
        else:
            log_success("Node.js version meets requirements")
            
    except Exception as e:
        log_warning(f"Could not check Node.js version: {e}")
    
    # Check npm version
    try:
        result = subprocess.run(['npm', '--version'], capture_output=True, text=True)
        npm_version = result.stdout.strip()
        log_success(f"npm version: {npm_version}")
    except Exception as e:
        log_warning(f"Could not check npm version: {e}")
    
    return True

def setup_next_js_app():
    """Set up the Next.js Mira Control application"""
    nextjs_path = Path("api/open-processing/mira-control-nextjs")
    
    if not nextjs_path.exists():
        log_error(f"Next.js application directory not found: {nextjs_path}")
        return False
    
    log_info(f"Setting up Next.js application in {nextjs_path}")
    
    # Check if package.json exists
    package_json = nextjs_path / "package.json"
    if not package_json.exists():
        log_error("package.json not found in Next.js directory")
        return False
    
    log_success("package.json found")
    
    # Install dependencies
    log_step("Installing Next.js dependencies (this may take a few minutes)...")
    if not run_command("npm install", "Installing dependencies", cwd=nextjs_path):
        log_error("Failed to install dependencies")
        return False
    
    # Optional: Build the application
    log_step("Building Next.js application...")
    if run_command("npm run build", "Building application", cwd=nextjs_path):
        log_success("Next.js application built successfully")
    else:
        log_warning("Build failed, but dependencies are installed")
    
    return True

def setup_node_api_service():
    """Set up the Node.js API service"""
    api_path = Path("api/open-processing")
    package_json = api_path / "package.json"
    
    if not package_json.exists():
        log_warning(f"No package.json found in {api_path}")
        return True  # Not an error, just no Node.js service to set up
    
    log_info(f"Setting up Node.js API service in {api_path}")
    
    # Install dependencies
    if not run_command("npm install", "Installing API dependencies", cwd=api_path):
        log_error("Failed to install API dependencies")
        return False
    
    log_success("Node.js API service dependencies installed")
    return True

def create_development_scripts():
    """Create helpful development scripts"""
    scripts = {
        'start_frontend.sh': """#!/bin/bash
# Start the Next.js development server
cd api/open-processing/mira-control-nextjs
npm run dev
""",
        'start_api.sh': """#!/bin/bash
# Start the Node.js API service
cd api/open-processing
npm start
""",
        'build_frontend.sh': """#!/bin/bash
# Build the Next.js application for production
cd api/open-processing/mira-control-nextjs
npm run build
npm run export
""",
        'start_electron.sh': """#!/bin/bash
# Start the Electron application
cd api/open-processing/mira-control-nextjs
npm run electron-dev
"""
    }
    
    log_step("Creating development scripts...")
    
    for script_name, content in scripts.items():
        try:
            with open(script_name, 'w') as f:
                f.write(content)
            os.chmod(script_name, 0o755)
            log_success(f"Created {script_name}")
        except Exception as e:
            log_warning(f"Failed to create {script_name}: {e}")

def verify_frontend_setup():
    """Verify that the frontend setup completed successfully"""
    log_step("Verifying frontend setup...")
    
    checks = []
    
    # Check Next.js dependencies
    nextjs_path = Path("api/open-processing/mira-control-nextjs")
    node_modules = nextjs_path / "node_modules"
    
    if node_modules.exists():
        log_success("Next.js node_modules directory exists")
        checks.append(True)
    else:
        log_error("Next.js node_modules directory not found")
        checks.append(False)
    
    # Check for key packages
    key_packages = ['next', 'react', 'electron']
    for package in key_packages:
        package_path = node_modules / package
        if package_path.exists():
            log_success(f"Package {package} installed")
            checks.append(True)
        else:
            log_warning(f"Package {package} not found")
            checks.append(False)
    
    success_rate = sum(checks) / len(checks) * 100
    log_info(f"Frontend verification: {sum(checks)}/{len(checks)} ({success_rate:.1f}%)")
    
    return success_rate >= 75

def main():
    """Main setup function"""
    print(f"{Colors.CYAN}🌐 Huddle Node Manager - Frontend Dependencies Setup{Colors.NC}")
    print("=" * 60)
    
    # 1. Check Node.js requirements
    if not check_node_requirements():
        log_error("Node.js requirements not met. Please install Node.js and npm first.")
        print(f"\n{Colors.BLUE}💡 To install Node.js:{Colors.NC}")
        print("  • Run: python3 setup_system_dependencies.py")
        print("  • Or manually: brew install node (macOS)")
        return False
    
    success = True
    
    # 2. Set up Next.js application
    print(f"\n{Colors.PURPLE}📱 Setting up Next.js Application...{Colors.NC}")
    success &= setup_next_js_app()
    
    # 3. Set up Node.js API service
    print(f"\n{Colors.PURPLE}🔧 Setting up Node.js API Service...{Colors.NC}")
    success &= setup_node_api_service()
    
    # 4. Create development scripts
    print(f"\n{Colors.PURPLE}📜 Creating Development Scripts...{Colors.NC}")
    create_development_scripts()
    
    # 5. Verify setup
    print(f"\n{Colors.PURPLE}🧪 Verifying Frontend Setup...{Colors.NC}")
    verified = verify_frontend_setup()
    
    # Summary
    print(f"\n{Colors.PURPLE}📋 Frontend Setup Summary{Colors.NC}")
    print("=" * 30)
    
    if success and verified:
        log_success("🎉 Frontend dependencies installed successfully!")
        print(f"\n{Colors.CYAN}🚀 Development Commands:{Colors.NC}")
        print("  • ./start_frontend.sh     - Start Next.js dev server")
        print("  • ./start_electron.sh     - Start Electron app")
        print("  • ./build_frontend.sh     - Build for production")
        print("  • ./start_api.sh          - Start Node.js API")
        
        print(f"\n{Colors.BLUE}📖 Manual Commands:{Colors.NC}")
        print("  • cd api/open-processing/mira-control-nextjs")
        print("  • npm run dev              - Development server")
        print("  • npm run build            - Production build")
        print("  • npm run electron         - Electron app")
        
    else:
        log_warning("⚠️ Some frontend components may not work properly")
        print(f"\n{Colors.BLUE}🔧 Troubleshooting:{Colors.NC}")
        print("  • Check Node.js version: node --version")
        print("  • Reinstall dependencies: cd api/open-processing/mira-control-nextjs && npm install")
        print("  • Clear cache: npm cache clean --force")
    
    return success and verified

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 