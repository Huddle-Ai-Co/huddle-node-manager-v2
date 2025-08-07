#!/usr/bin/env python3
"""
Platform Adaptive Configuration
Automatically selects optimal model and settings for different platforms
"""

import os
import sys
import platform
import torch
from pathlib import Path
from typing import Dict, Any, Optional
import json

class PlatformAdaptiveConfig:
    def __init__(self):
        self.platform = self._detect_platform()
        self.device_capabilities = self._detect_device_capabilities()
        self.available_models = self._scan_available_models()
        
    def _detect_platform(self) -> str:
        """Detect the current platform"""
        system = platform.system().lower()
        machine = platform.machine().lower()
        
        if system == "darwin":
            # Check if it's Apple Silicon
            if "arm" in machine or "aarch64" in machine:
                return "macos_apple_silicon"
            else:
                return "macos_intel"
        elif system == "linux":
            if torch.cuda.is_available():
                return "linux_cuda"
            else:
                return "linux_cpu"
        elif system == "windows":
            if torch.cuda.is_available():
                return "windows_cuda"
            else:
                return "windows_cpu"
        else:
            return "unknown"
    
    def _detect_device_capabilities(self) -> Dict[str, Any]:
        """Detect device capabilities"""
        capabilities = {
            "platform": self.platform,
            "cuda_available": torch.cuda.is_available(),
            "mps_available": hasattr(torch.backends, 'mps') and torch.backends.mps.is_available(),
            "cpu_cores": os.cpu_count(),
            "device_count": 0
        }
        
        if capabilities["cuda_available"]:
            capabilities["device_count"] = torch.cuda.device_count()
            capabilities["cuda_version"] = torch.version.cuda
            capabilities["gpu_memory"] = []
            for i in range(capabilities["device_count"]):
                memory = torch.cuda.get_device_properties(i).total_memory / (1024**3)
                capabilities["gpu_memory"].append(f"{memory:.1f}GB")
        
        if capabilities["mps_available"]:
            capabilities["mps_device"] = "Apple Silicon GPU"
        
        return capabilities
    
    def _scan_available_models(self) -> Dict[str, bool]:
        """Scan for available model variants"""
        models = {}
        model_variants = [
            "llama-3.2-3b-quantized-q4km",  # NEW: Prioritize quantized GGUF model
            "llama-3.2-3b-instruct-optimized", 
            "llama-3.2-3b-instruct",
            "llama-3.2-3b-instruct-quantized",
            "llama-3.2-3b-instruct-backup"
        ]
        
        # Use the production bundled_models directory
        bundled_models_dir = Path.home() / ".huddle-node-manager" / "bundled_models"
        
        for variant in model_variants:
            model_path = bundled_models_dir / variant
            models[variant] = model_path.exists()
        
        return models
    
    def get_optimal_model_config(self) -> Dict[str, Any]:
        """Get optimal model configuration for current platform"""
        
        config = {
            "model_path": None,
            "optimization_strategy": None,
            "device": "auto",
            "dtype": "auto",
            "batch_size": 4,
            "max_concurrent_requests": 8,
            "memory_fraction": 0.25,
            "use_cache": True,
            "attention_implementation": "auto",
            "conservative_mode": False,
            "reasoning": []
        }
        
        # Platform-specific optimizations
        if self.platform == "macos_apple_silicon":
            config.update(self._get_macos_apple_silicon_config())
        elif self.platform == "macos_intel":
            config.update(self._get_macos_intel_config())
        elif self.platform == "linux_cuda":
            config.update(self._get_linux_cuda_config())
        elif self.platform == "linux_cpu":
            config.update(self._get_linux_cpu_config())
        elif self.platform == "windows_cuda":
            config.update(self._get_windows_cuda_config())
        else:
            config.update(self._get_fallback_config())
        
        return config
    
    def _get_macos_apple_silicon_config(self) -> Dict[str, Any]:
        """Configuration for macOS with Apple Silicon"""
        config = {
            "model_path": "llama-3.2-3b-quantized-q4km",
            "optimization_strategy": "apple_silicon_quantized_gguf",
            "device": "mps", 
            "dtype": "q4_k_m",  # GGUF quantization type
            "model_format": "gguf",
            "quantization": "Q4_K_M",
            "batch_size": 12,  # Higher batch size due to memory savings
            "max_concurrent_requests": 24,  # More concurrent requests
            "memory_fraction": 0.15,  # Much lower memory usage
            "attention_implementation": "llama_cpp",
            "conservative_mode": False,
            "reasoning": [
                "Using quantized GGUF model (1.9GB vs 6GB)",
                "Q4_K_M quantization for 99% quality at 3x speed",
                "MPS device for GPU acceleration",
                "Higher batch size due to memory efficiency",
                "llama.cpp for optimized GGUF inference"
            ]
        }
        
        # Fallback hierarchy: quantized → optimized → original
        if not self.available_models.get("llama-3.2-3b-quantized-q4km", False):
            if self.available_models.get("llama-3.2-3b-instruct-optimized", False):
                config["model_path"] = "llama-3.2-3b-instruct-optimized"
                config["optimization_strategy"] = "apple_silicon_fallback_optimized"
                config["dtype"] = "float16"
                config["model_format"] = "pytorch"
                config["reasoning"].append("Quantized model not found, using old optimized version")
            else:
                config["model_path"] = "llama-3.2-3b-instruct"
                config["optimization_strategy"] = "apple_silicon_fallback_original"
                config["dtype"] = "float16"
                config["model_format"] = "pytorch"
                config["reasoning"].append("No optimized models found, using original")
        
        return config
    
    def _get_macos_intel_config(self) -> Dict[str, Any]:
        """Configuration for macOS with Intel"""
        config = {
            "model_path": "llama-3.2-3b-instruct-optimized",
            "optimization_strategy": "intel_macos_optimized",
            "device": "cpu",
            "dtype": "float16",
            "batch_size": 4,
            "max_concurrent_requests": 8,
            "memory_fraction": 0.20,
            "attention_implementation": "eager",
            "conservative_mode": True,
            "reasoning": [
                "Intel Mac - using CPU optimization",
                "Float16 for memory efficiency",
                "Conservative settings for stability",
                "Lower batch size for Intel CPU"
            ]
        }
        
        if not self.available_models.get("llama-3.2-3b-instruct-optimized", False):
            config["model_path"] = "llama-3.2-3b-instruct"
            config["optimization_strategy"] = "intel_macos_fallback"
            config["reasoning"].append("Optimized model not found, using original")
        
        return config
    
    def _get_linux_cuda_config(self) -> Dict[str, Any]:
        """Configuration for Linux with CUDA"""
        config = {
            "model_path": "llama-3.2-3b-quantized-q4km",
            "optimization_strategy": "linux_cuda_quantized_gguf",
            "device": "cuda",
            "dtype": "q4_k_m",
            "model_format": "gguf",
            "quantization": "Q4_K_M",
            "batch_size": 16,  # Even higher for CUDA
            "max_concurrent_requests": 32,
            "memory_fraction": 0.20,  # Much lower memory usage
            "attention_implementation": "llama_cpp",
            "conservative_mode": False,
            "reasoning": [
                "Using quantized GGUF model (1.9GB vs 6GB)",
                "Q4_K_M quantization for 99% quality at 3x speed",
                "Linux with CUDA - maximum performance",
                "llama.cpp CUDA acceleration",
                "Higher batch size due to memory efficiency"
            ]
        }
        
        # Fallback hierarchy: quantized → optimized → original  
        if not self.available_models.get("llama-3.2-3b-quantized-q4km", False):
            if self.available_models.get("llama-3.2-3b-instruct-optimized", False):
                config["model_path"] = "llama-3.2-3b-instruct-optimized"
                config["optimization_strategy"] = "linux_cuda_fallback_optimized"
                config["dtype"] = "float16"
                config["model_format"] = "pytorch"
                # Check if flash attention is available
                try:
                    import flash_attn
                    config["attention_implementation"] = "flash_attention_2"
                except ImportError:
                    config["attention_implementation"] = "eager"
                    config["reasoning"].append("Flash attention not available, using eager")
                config["reasoning"].append("Quantized model not found, using old optimized version")
            else:
                config["model_path"] = "llama-3.2-3b-instruct"
                config["optimization_strategy"] = "linux_cuda_fallback_original"
                config["dtype"] = "float16"
                config["model_format"] = "pytorch"
                config["attention_implementation"] = "eager"
                config["reasoning"].append("No optimized models found, using original")
        
        return config
    
    def _get_linux_cpu_config(self) -> Dict[str, Any]:
        """Configuration for Linux CPU-only"""
        config = {
            "model_path": "llama-3.2-3b-instruct-optimized",
            "optimization_strategy": "linux_cpu_optimized",
            "device": "cpu",
            "dtype": "float16",
            "batch_size": 4,
            "max_concurrent_requests": 8,
            "memory_fraction": 0.20,
            "attention_implementation": "eager",
            "conservative_mode": True,
            "reasoning": [
                "Linux CPU-only system",
                "Conservative settings for stability",
                "Float16 for memory efficiency",
                "Lower batch size for CPU"
            ]
        }
        
        if not self.available_models.get("llama-3.2-3b-instruct-optimized", False):
            config["model_path"] = "llama-3.2-3b-instruct"
            config["optimization_strategy"] = "linux_cpu_fallback"
            config["reasoning"].append("Optimized model not found, using original")
        
        return config
    
    def _get_windows_cuda_config(self) -> Dict[str, Any]:
        """Configuration for Windows with CUDA"""
        config = {
            "model_path": "llama-3.2-3b-instruct-optimized",
            "optimization_strategy": "windows_cuda_optimized",
            "device": "cuda",
            "dtype": "float16",
            "batch_size": 8,
            "max_concurrent_requests": 16,
            "memory_fraction": 0.25,
            "attention_implementation": "eager",
            "conservative_mode": False,
            "reasoning": [
                "Windows with CUDA",
                "Float16 for memory efficiency",
                "Moderate batch size for Windows stability",
                "Eager attention for compatibility"
            ]
        }
        
        if not self.available_models.get("llama-3.2-3b-instruct-optimized", False):
            config["model_path"] = "llama-3.2-3b-instruct"
            config["optimization_strategy"] = "windows_cuda_fallback"
            config["reasoning"].append("Optimized model not found, using original")
        
        return config
    
    def _get_fallback_config(self) -> Dict[str, Any]:
        """Fallback configuration for unknown platforms"""
        config = {
            "model_path": "llama-3.2-3b-instruct",
            "optimization_strategy": "fallback",
            "device": "cpu",
            "dtype": "float32",
            "batch_size": 2,
            "max_concurrent_requests": 4,
            "memory_fraction": 0.15,
            "attention_implementation": "eager",
            "conservative_mode": True,
            "reasoning": [
                "Unknown platform - using conservative settings",
                "CPU-only for maximum compatibility",
                "Float32 for stability",
                "Minimal batch size for safety"
            ]
        }
        
        return config
    
    def generate_server_config(self) -> Dict[str, Any]:
        """Generate complete server configuration"""
        model_config = self.get_optimal_model_config()
        
        server_config = {
            "platform_info": {
                "platform": self.platform,
                "capabilities": self.device_capabilities,
                "available_models": self.available_models
            },
            "model_config": model_config,
            "server_settings": {
                "host": "0.0.0.0",
                "port": 8002,
                "workers": 1 if self.platform == "macos_apple_silicon" else 2,
                "worker_class": "uvicorn.workers.UvicornWorker",
                "max_requests": 1000,
                "max_requests_jitter": 100,
                "keepalive": 5,
                "timeout_keep_alive": 30
            },
            "optimization_settings": {
                "enable_memory_pooling": True,
                "enable_gradient_checkpointing": True,
                "enable_attention_slicing": True,
                "use_flash_attention": model_config.get("attention_implementation") == "flash_attention_2"
            }
        }
        
        return server_config
    
    def save_config(self, filename: str = "platform_config.json"):
        """Save configuration to file"""
        config = self.generate_server_config()
        
        with open(filename, 'w') as f:
            json.dump(config, f, indent=2)
        
        return filename
    
    def print_config_summary(self):
        """Print a summary of the configuration"""
        config = self.get_optimal_model_config()
        
        print("🔧 Platform Adaptive Configuration")
        print("=" * 50)
        print(f"Platform: {self.platform}")
        print(f"Model: {config['model_path']}")
        print(f"Strategy: {config['optimization_strategy']}")
        print(f"Device: {config['device']}")
        print(f"Batch Size: {config['batch_size']}")
        print(f"Concurrent Requests: {config['max_concurrent_requests']}")
        print(f"Conservative Mode: {config['conservative_mode']}")
        print()
        print("🎯 Reasoning:")
        for reason in config['reasoning']:
            print(f"   • {reason}")
        print()
        print("📊 Device Capabilities:")
        for key, value in self.device_capabilities.items():
            if key != "platform":
                print(f"   • {key}: {value}")

def get_platform_config() -> Dict[str, Any]:
    """Get platform configuration for the current system"""
    config = PlatformAdaptiveConfig()
    model_config = config.get_optimal_model_config()
    
    # Add platform information to the config
    model_config["platform"] = config.platform
    model_config["device_capabilities"] = config.device_capabilities
    model_config["available_models"] = config.available_models
    
    return model_config

def main():
    """Main function to demonstrate platform detection"""
    config = PlatformAdaptiveConfig()
    config.print_config_summary()
    
    # Save configuration
    filename = config.save_config()
    print(f"\n💾 Configuration saved to: {filename}")
    
    return config

if __name__ == "__main__":
    main() 