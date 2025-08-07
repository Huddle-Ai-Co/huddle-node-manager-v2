#!/usr/bin/env python3
import os
import sys
import importlib.util
import traceback

print("\n\033[1;33mPython Information:\033[0m")
print(f"Python version: {sys.version}")
print(f"Python executable: {sys.executable}")
print(f"Current directory: {os.getcwd()}")

# Add parent directory to path to find api module
sys.path.append(os.path.abspath(".."))

# Try to import torch
print("\n\033[1;33mTesting PyTorch installation:\033[0m")
try:
    import torch
    print(f"\033[0;32m✓ PyTorch installed: {torch.__version__}\033[0m")
    print(f"\033[0;32m✓ CUDA available: {torch.cuda.is_available()}\033[0m")
    print(f"\033[0;32m✓ Device: {torch.device('cuda' if torch.cuda.is_available() else 'cpu')}\033[0m")
except ImportError as e:
    print(f"\033[0;31m✗ Failed to import torch: {e}\033[0m")
    print("\033[1;33mTraceback:\033[0m")
    traceback.print_exc()

# Try to import API modules
print("\n\033[1;33mTesting API imports:\033[0m")
try:
    from api.apim import client as client_module
    print("\033[0;32m✓ Successfully imported api.apim.client\033[0m")
    
    # Check if module has the APIMClient class
    if hasattr(client_module, "APIMClient"):
        print("\033[0;32m✓ APIMClient class found\033[0m")
        
        # Check if client is an instance of APIMClient
        if hasattr(client_module, "client") and isinstance(client_module.client, client_module.APIMClient):
            print("\033[0;32m✓ client is an instance of APIMClient\033[0m")
            client = client_module.client
        else:
            print("\033[0;31m✗ client is not an instance of APIMClient, creating our own instance\033[0m")
            # Create our own instance
            client = client_module.APIMClient()
            print("\033[0;32m✓ Created our own APIMClient instance\033[0m")
        
        # Try to use client methods
        print("\n\033[1;33mTesting client methods:\033[0m")
        
        # Get API key
        from api.apim.common import api_key
        key = api_key.get_api_key()
        if key:
            print(f"\033[0;32m✓ API Key found: {key[:4]}...{key[-4:]}\033[0m")
            
            # Verify API key
            try:
                success, message = client.verify_api_key()
                print(f"\033[0;32m✓ Verification: {'Success' if success else 'Failed'} - {message}\033[0m")
                
                # Test each service
                print("\n\033[1;33mTesting services:\033[0m")
                
                # Test embeddings
                print("- Embeddings service:", end=" ")
                success, message = client.embeddings.verify_api_key()
                print("\033[0;32mAvailable\033[0m" if success else "\033[0;31mUnavailable\033[0m")
                
                # Test OCR
                print("- OCR service:", end=" ")
                success, message = client.ocr.verify_api_key()
                print("\033[0;32mAvailable\033[0m" if success else "\033[0;31mUnavailable\033[0m")
                
                # Test NLP
                print("- NLP service:", end=" ")
                success, message = client.nlp.verify_api_key()
                print("\033[0;32mAvailable\033[0m" if success else "\033[0;31mUnavailable\033[0m")
                
                # Test Transcriber
                print("- Transcriber service:", end=" ")
                success, message = client.transcriber.verify_api_key()
                print("\033[0;32mAvailable\033[0m" if success else "\033[0;31mUnavailable\033[0m")
            except Exception as e:
                print(f"\033[0;31m✗ Error testing client methods: {e}\033[0m")
                traceback.print_exc()
        else:
            print("\033[0;31m✗ No API key found\033[0m")
    else:
        print("\033[0;31m✗ APIMClient class not found\033[0m")
        
except ImportError as e:
    print(f"\033[0;31m✗ Failed to import api.apim.client: {e}\033[0m")
    print("\033[1;33mTraceback:\033[0m")
    traceback.print_exc()

# Check for API key
print("\n\033[1;33mChecking for API key:\033[0m")
api_key_path = os.path.expanduser("~/.ipfs/api_keys")
if os.path.exists(api_key_path):
    print(f"\033[0;32m✓ API key directory found: {api_key_path}\033[0m")
    # List files in the directory
    files = os.listdir(api_key_path)
    if files:
        print("\033[0;32m✓ API key files found:\033[0m")
        for file in files:
            print(f"  - {file}")
    else:
        print("\033[0;31m✗ No API key files found\033[0m")
else:
    print(f"\033[0;31m✗ API key directory not found: {api_key_path}\033[0m")

# Check for configuration file
config_path = os.path.expanduser("~/.ipfs/apim_config.json")
if os.path.exists(config_path):
    print(f"\033[0;32m✓ API configuration file found: {config_path}\033[0m")
    with open(config_path, 'r') as f:
        print("\033[1;33mConfiguration content:\033[0m")
        print(f.read())
else:
    print(f"\033[0;31m✗ API configuration file not found: {config_path}\033[0m") 