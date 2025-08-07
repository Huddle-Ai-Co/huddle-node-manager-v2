#!/usr/bin/env python3
"""
Fast NeuroKit Setup - Downloads and installs NeuroKit using ZIP instead of git clone
"""

import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
import time
from pathlib import Path

def log_info(msg):
    print(f"ℹ️  {msg}")

def log_success(msg):
    print(f"✅ {msg}")

def log_error(msg):
    print(f"❌ {msg}")

def log_step(msg):
    print(f"🔄 {msg}")

def log_warning(msg):
    print(f"⚠️  {msg}")

def download_with_retry(url, file_path, max_retries=3):
    """Download file with retry logic for network resilience"""
    for attempt in range(max_retries):
        try:
            log_step(f"Downloading NeuroKit ZIP file (attempt {attempt + 1}/{max_retries})...")
            
            with urllib.request.urlopen(url) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                
                with open(file_path, 'wb') as f:
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
            log_success(f"Downloaded NeuroKit ZIP ({downloaded / 1024 / 1024:.1f}MB)")
            return True
            
        except Exception as e:
            log_warning(f"Download attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                log_info(f"Retrying in 2 seconds...")
                time.sleep(2)
            else:
                log_error(f"All download attempts failed")
                return False
    
    return False

def setup_neurokit_fast():
    """Setup NeuroKit using ZIP download for speed"""
    
    # Configuration
    neurokit_zip_url = "https://github.com/neuropsychology/NeuroKit/archive/refs/heads/master.zip"
    
    # PRODUCTION INSTALLATION: Always use standardized user home location
    bundled_models_dir = Path.home() / ".huddle-node-manager" / "bundled_models"
    
    # Ensure the directory exists
    bundled_models_dir.mkdir(parents=True, exist_ok=True)
    
    neurokit_dir = bundled_models_dir / "NeuroKit"
    
    # Remove existing directory
    if neurokit_dir.exists():
        log_info("Removing existing NeuroKit directory...")
        shutil.rmtree(neurokit_dir)
    
    # Download ZIP file with retry logic
    zip_path = bundled_models_dir / "NeuroKit.zip"
    
    if not download_with_retry(neurokit_zip_url, zip_path):
        return False
    
    # Extract ZIP file
    log_step("Extracting NeuroKit...")
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(bundled_models_dir)
        
        # Rename extracted directory
        extracted_dir = bundled_models_dir / "NeuroKit-master"
        if extracted_dir.exists():
            extracted_dir.rename(neurokit_dir)
        
        # Clean up ZIP file
        zip_path.unlink()
        
        log_success("Extracted NeuroKit successfully")
        
    except Exception as e:
        log_error(f"Failed to extract NeuroKit: {e}")
        if zip_path.exists():
            zip_path.unlink()
        return False
    
    # Install from setup.py
    log_step("Installing NeuroKit from setup.py...")
    try:
        # Change to NeuroKit directory
        original_cwd = os.getcwd()
        os.chdir(neurokit_dir)
        
        # Install using pip install directly (avoiding deprecated setuptools)
        subprocess.run([
            sys.executable, "-m", "pip", "install", "."
        ], check=True, capture_output=True)
        
        # Return to original directory
        os.chdir(original_cwd)
        
        log_success("Installed NeuroKit successfully")
        
    except subprocess.CalledProcessError as e:
        log_error(f"Failed to install NeuroKit: {e.stderr.decode()}")
        os.chdir(original_cwd)
        return False
    except Exception as e:
        log_error(f"Error installing NeuroKit: {e}")
        try:
            os.chdir(original_cwd)
        except:
            pass
        return False
    
    # Test import
    log_step("Testing NeuroKit import...")
    try:
        # Test the actual installed package, not the directory
        import neurokit2
        log_success("NeuroKit import successful!")
        return True
        
    except ImportError as e:
        log_error(f"NeuroKit import failed: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Fast NeuroKit Setup")
    print("=" * 30)
    
    success = setup_neurokit_fast()
    
    if success:
        print("\n🎉 NeuroKit setup completed successfully!")
        print("You can now use neurokit2 in your scripts.")
    else:
        print("\n❌ NeuroKit setup failed.")
        sys.exit(1) 