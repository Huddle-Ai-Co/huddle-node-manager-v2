#!/usr/bin/env python3
"""
Optimized Resource Allocation FastAPI Llama Server
Allocates more resources and uses better memory management
Supports both GGUF and PyTorch models
"""

import os
import torch
import time
import json
import psutil
import gc
import subprocess
import re
from typing import Optional, Dict, Any, AsyncGenerator, List
from pydantic import BaseModel, Field
from transformers import AutoTokenizer, AutoModelForCausalLM
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import uvicorn
import threading
from contextlib import asynccontextmanager
from dataclasses import dataclass, asdict
from pathlib import Path

# Set MPS memory management environment variables
os.environ["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"  # Disable upper limit for memory allocations
os.environ["PYTORCH_MPS_LOW_WATERMARK_RATIO"] = "0.0"   # Disable lower limit
os.environ["TRANSFORMERS_VERBOSITY"] = "error"  # Reduce warning messages

# Try importing llama-cpp-python for GGUF support
try:
    from llama_cpp import Llama
    LLAMA_CPP_AVAILABLE = True
    print("✅ llama-cpp-python available for GGUF models")
except ImportError:
    LLAMA_CPP_AVAILABLE = False
    print("⚠️ llama-cpp-python not available - GGUF models disabled")

# Import vLLM-style optimizations
try:
    from vllm_style_optimizer import VLLMStyleOptimizer, apply_vllm_optimizations, get_vllm_stats
    VLLM_OPTIMIZATIONS_AVAILABLE = True
except ImportError:
    VLLM_OPTIMIZATIONS_AVAILABLE = False
    print("⚠️ vLLM-style optimizations not available")

# Import device detection classes
from device_detection_test import DeviceDetector, SystemInfo, DeviceInfo, ResourceAllocation, ProcessInfo

# Import resource monitor
from resource_monitor import get_global_monitor, start_global_monitoring, stop_global_monitoring, get_global_monitor_with_device

# Import platform-adaptive configuration
from platform_adaptive_config import get_platform_config

# OpenAI-compatible request models
class ChatMessage(BaseModel):
    role: str = Field(..., description="The role of the message author (system, user, assistant)")
    content: str = Field(..., description="The content of the message")

class ChatCompletionRequest(BaseModel):
    model: str = Field(default="HuddleAI", description="Model name")
    messages: List[ChatMessage] = Field(..., description="List of messages in the conversation")
    max_tokens: Optional[int] = Field(default=100, ge=1, le=32000, description="Maximum tokens to generate")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: Optional[float] = Field(default=0.9, ge=0.0, le=1.0, description="Top-p sampling parameter")
    frequency_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Frequency penalty")
    presence_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Presence penalty")
    stream: Optional[bool] = Field(default=False, description="Whether to stream the response")
    stop: Optional[List[str]] = Field(default=None, description="Stop sequences")
    user: Optional[str] = Field(default=None, description="User identifier")

class CompletionRequest(BaseModel):
    model: str = Field(default="HuddleAI", description="Model name")
    prompt: str = Field(..., description="The input prompt for text generation")
    max_tokens: Optional[int] = Field(default=100, ge=1, le=32000, description="Maximum tokens to generate")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: Optional[float] = Field(default=0.9, ge=0.0, le=1.0, description="Top-p sampling parameter")
    frequency_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Frequency penalty")
    presence_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Presence penalty")
    stream: Optional[bool] = Field(default=False, description="Whether to stream the response")
    stop: Optional[List[str]] = Field(default=None, description="Stop sequences")
    user: Optional[str] = Field(default=None, description="User identifier")

# OpenAI-compatible response models
class ChatCompletionChoice(BaseModel):
    index: int
    message: ChatMessage
    finish_reason: str

class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: Dict[str, int]

class CompletionChoice(BaseModel):
    index: int
    text: str
    finish_reason: str

class CompletionResponse(BaseModel):
    id: str
    object: str = "text_completion"
    created: int
    model: str
    choices: List[CompletionChoice]
    usage: Dict[str, int]

# Legacy request model (for backward compatibility)
class GenerateRequest(BaseModel):
    prompt: str = Field(..., description="The input prompt for text generation")
    max_tokens: int = Field(default=100, ge=1, le=32000, description="Maximum tokens to generate")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: float = Field(default=0.9, ge=0.0, le=1.0, description="Top-p sampling parameter")
    repetition_penalty: float = Field(default=1.1, ge=1.0, le=2.0, description="Repetition penalty")
    stream: bool = Field(default=True, description="Whether to stream the response")
    use_optimizations: bool = Field(default=True, description="Use performance optimizations")

class HealthResponse(BaseModel):
    status: str = Field(..., description="Server status")
    model_loaded: bool = Field(..., description="Whether model is loaded")
    device: str = Field(..., description="Device being used")
    uptime: float = Field(..., description="Server uptime in seconds")
    memory_usage: Dict[str, Any] = Field(..., description="Memory usage information")

# Global model instance
model_instance = None
start_time = time.time()

# Global conversation state for multi-turn chat
conversation_sessions = {}

# Alert aggregation system
class AlertAggregator:
    def __init__(self):
        self.alert_counts = {}
        self.last_alert_time = {}
        self.alert_cooldown = 30.0  # 30 seconds between similar alerts
        self.summary_interval = 60.0  # 60 seconds for summary
        self.last_summary_time = time.time()
    
    def should_show_alert(self, alert_key: str) -> bool:
        """Check if alert should be shown based on cooldown"""
        current_time = time.time()
        if alert_key not in self.last_alert_time:
            self.last_alert_time[alert_key] = current_time
            return True
        
        if current_time - self.last_alert_time[alert_key] > self.alert_cooldown:
            self.last_alert_time[alert_key] = current_time
            return True
        
        return False
    
    def record_alert(self, alert_key: str):
        """Record an alert for aggregation"""
        if alert_key not in self.alert_counts:
            self.alert_counts[alert_key] = 0
        self.alert_counts[alert_key] += 1
    
    def get_summary(self) -> str:
        """Get a summary of recent alerts"""
        if not self.alert_counts:
            return ""
        
        summary_lines = ["📊 Resource Alert Summary:"]
        for alert_key, count in self.alert_counts.items():
            if count > 1:
                summary_lines.append(f"   • {alert_key}: {count} times")
        
        # Clear counts after summary
        self.alert_counts.clear()
        return "\n".join(summary_lines)

# Global alert aggregator
alert_aggregator = AlertAggregator()

class OptimizedLlamaModel:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_type = None  # "gguf" or "pytorch"
        
        # Initialize improved device detector
        self.device_detector = DeviceDetector()
        self.device = self.device_detector.best_device
        self.is_loaded = False
        self.load_lock = threading.Lock()
        
        # Get dynamic resource allocation from device detector
        allocation_info = self.device_detector.resource_allocation
        self.max_memory_gb = allocation_info.recommended_memory_gb
        self.use_conservative_settings = allocation_info.use_conservative
        
        # Performance optimizations - adjust based on system load
        self.use_mixed_precision = True
        self.batch_size = allocation_info.batch_size
        self.num_attention_heads = allocation_info.attention_heads
        self.hidden_size = allocation_info.hidden_size
        
        # Initialize resource monitor with device detector integration
        self.resource_monitor = get_global_monitor_with_device(self.device_detector)
        
        self.resource_monitor.add_alert_callback(self._handle_resource_alert)
        
        # Ensure only one monitoring instance is active
        if not self.resource_monitor.monitoring:
            self.resource_monitor.start_monitoring(interval=10.0)
        
        # vLLM-style optimizations
        if VLLM_OPTIMIZATIONS_AVAILABLE:
            self.vllm_optimizer = VLLMStyleOptimizer(device=self.device)
            print("🚀 vLLM-style optimizations enabled")
        else:
            self.vllm_optimizer = None
            print("⚠️ Using standard optimizations")
        
        print(f"🎯 Model Configuration:")
        print(f"   Device: {self.device}")
        print(f"   Max Memory: {self.max_memory_gb:.1f}GB")
        print(f"   Conservative Mode: {self.use_conservative_settings}")
        print(f"   Batch Size: {self.batch_size}")
        print(f"   Attention Heads: {self.num_attention_heads}")
        print(f"   Hidden Size: {self.hidden_size}")
        
    def detect_best_device(self) -> str:
        """Detect the best available device across platforms"""
        return self.device_detector.best_device
    
    def detect_gpu_capabilities(self) -> Dict[str, Any]:
        """Detect GPU capabilities using improved device detector"""
        device_config = self.device_detector.generate_config()
        
        gpu_info = {
            'gpu_model': device_config["device_info"]["device_name"],
            'gpu_cores': 0,  # Will be filled by device-specific detection
            'total_memory_gb': device_config["system_info"]["total_memory_gb"],
            'recommended_memory_gb': device_config["resource_allocation"]["recommended_memory_gb"],
            'device_type': self.device,
            'performance_tier': device_config["device_info"]["performance_tier"],
            'platform': device_config["system_info"]["platform"],
            'allocation_info': device_config["resource_allocation"]
        }
        
        # Add device-specific info
        if self.device == "mps":
            gpu_info.update(self._detect_apple_silicon())
        elif self.device == "cuda":
            gpu_info.update(self._detect_nvidia_gpu())
        elif self.device == "rocm":
            gpu_info.update(self._detect_amd_gpu())
        else:
            gpu_info.update(self._detect_cpu_system())
        
        return gpu_info
    
    def _detect_apple_silicon(self) -> Dict[str, Any]:
        """Detect Apple Silicon GPU capabilities"""
        import subprocess
        import re
        
        gpu_info = {
            'gpu_model': 'Unknown',
            'gpu_cores': 0,
            'total_memory_gb': 16,
            'recommended_memory_gb': 12,
            'performance_tier': 'Standard'
        }
        
        try:
            # Get GPU info using system_profiler
            result = subprocess.run(['system_profiler', 'SPDisplaysDataType'], 
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                output = result.stdout
                
                # Extract GPU model
                gpu_match = re.search(r'Chipset Model:\s*(.+)', output)
                if gpu_match:
                    gpu_info['gpu_model'] = gpu_match.group(1).strip()
                
                # Get total system memory
                memory_result = subprocess.run(['sysctl', '-n', 'hw.memsize'], 
                                             capture_output=True, text=True)
                if memory_result.returncode == 0:
                    total_bytes = int(memory_result.stdout.strip())
                    gpu_info['total_memory_gb'] = total_bytes / (1024**3)
                
                # Auto-scale based on GPU model
                gpu_model = gpu_info['gpu_model'].lower()
                
                if 'm1 max' in gpu_model or 'm2 max' in gpu_model or 'm3 max' in gpu_model:
                    gpu_info['performance_tier'] = 'Pro'
                    gpu_info['recommended_memory_gb'] = min(20, int(gpu_info['total_memory_gb'] * 0.8))
                    gpu_info['gpu_cores'] = 32
                elif 'm1 pro' in gpu_model or 'm2 pro' in gpu_model or 'm3 pro' in gpu_model:
                    gpu_info['performance_tier'] = 'Pro'
                    gpu_info['recommended_memory_gb'] = min(16, int(gpu_info['total_memory_gb'] * 0.75))
                    gpu_info['gpu_cores'] = 16
                elif 'm1 ultra' in gpu_model or 'm2 ultra' in gpu_model or 'm3 ultra' in gpu_model:
                    gpu_info['performance_tier'] = 'Ultra'
                    gpu_info['recommended_memory_gb'] = min(32, int(gpu_info['total_memory_gb'] * 0.85))
                    gpu_info['gpu_cores'] = 64
                elif 'm1' in gpu_model or 'm2' in gpu_model or 'm3' in gpu_model:
                    gpu_info['performance_tier'] = 'Standard'
                    gpu_info['recommended_memory_gb'] = min(12, int(gpu_info['total_memory_gb'] * 0.7))
                    gpu_info['gpu_cores'] = 8
                    
        except Exception as e:
            print(f"⚠️ Could not detect Apple Silicon details: {e}")
            
        return gpu_info
    
    def _detect_nvidia_gpu(self) -> Dict[str, Any]:
        """Detect NVIDIA GPU capabilities"""
        gpu_info = {
            'gpu_model': 'Unknown',
            'gpu_cores': 0,
            'total_memory_gb': 16,
            'recommended_memory_gb': 12,
            'performance_tier': 'Standard'
        }
        
        try:
            # Get GPU info from PyTorch
            if torch.cuda.is_available():
                gpu_name = torch.cuda.get_device_name(0)
                gpu_info['gpu_model'] = gpu_name
                
                # Get GPU memory
                gpu_memory = torch.cuda.get_device_properties(0).total_memory
                gpu_info['total_memory_gb'] = gpu_memory / (1024**3)
                
                # Auto-scale based on GPU model
                gpu_name_lower = gpu_name.lower()
                
                if 'rtx 4090' in gpu_name_lower or 'rtx 4080' in gpu_name_lower:
                    gpu_info['performance_tier'] = 'Ultra'
                    gpu_info['recommended_memory_gb'] = min(24, int(gpu_info['total_memory_gb'] * 0.9))
                    gpu_info['gpu_cores'] = 10000  # Approximate CUDA cores
                elif 'rtx 3090' in gpu_name_lower or 'rtx 3080' in gpu_name_lower:
                    gpu_info['performance_tier'] = 'Pro'
                    gpu_info['recommended_memory_gb'] = min(20, int(gpu_info['total_memory_gb'] * 0.85))
                    gpu_info['gpu_cores'] = 8000
                elif 'rtx 4070' in gpu_name_lower or 'rtx 4060' in gpu_name_lower:
                    gpu_info['performance_tier'] = 'Pro'
                    gpu_info['recommended_memory_gb'] = min(16, int(gpu_info['total_memory_gb'] * 0.8))
                    gpu_info['gpu_cores'] = 5000
                elif 'gtx' in gpu_name_lower or 'rtx' in gpu_name_lower:
                    gpu_info['performance_tier'] = 'Standard'
                    gpu_info['recommended_memory_gb'] = min(12, int(gpu_info['total_memory_gb'] * 0.75))
                    gpu_info['gpu_cores'] = 3000
                else:
                    gpu_info['performance_tier'] = 'Legacy'
                    gpu_info['recommended_memory_gb'] = min(8, int(gpu_info['total_memory_gb'] * 0.7))
                    gpu_info['gpu_cores'] = 1000
                    
        except Exception as e:
            print(f"⚠️ Could not detect NVIDIA GPU details: {e}")
            
        return gpu_info
    
    def _detect_amd_gpu(self) -> Dict[str, Any]:
        """Detect AMD GPU capabilities"""
        gpu_info = {
            'gpu_model': 'Unknown',
            'gpu_cores': 0,
            'total_memory_gb': 16,
            'recommended_memory_gb': 12,
            'performance_tier': 'Standard'
        }
        
        try:
            # Try to get AMD GPU info (ROCm support is limited)
            gpu_info['gpu_model'] = 'AMD GPU (ROCm)'
            gpu_info['performance_tier'] = 'Standard'
            gpu_info['recommended_memory_gb'] = 12
            gpu_info['gpu_cores'] = 2000  # Approximate
            
        except Exception as e:
            print(f"⚠️ Could not detect AMD GPU details: {e}")
            
        return gpu_info
    
    def _detect_cpu_system(self) -> Dict[str, Any]:
        """Detect CPU system capabilities"""
        import psutil
        
        gpu_info = {
            'gpu_model': 'CPU Only',
            'gpu_cores': psutil.cpu_count(),
            'total_memory_gb': psutil.virtual_memory().total / (1024**3),
            'recommended_memory_gb': 8,
            'performance_tier': 'Legacy'
        }
        
        # Scale based on CPU cores
        cpu_cores = psutil.cpu_count()
        if cpu_cores >= 16:
            gpu_info['performance_tier'] = 'Pro'
            gpu_info['recommended_memory_gb'] = min(12, int(gpu_info['total_memory_gb'] * 0.6))
        elif cpu_cores >= 8:
            gpu_info['performance_tier'] = 'Standard'
            gpu_info['recommended_memory_gb'] = min(8, int(gpu_info['total_memory_gb'] * 0.5))
        else:
            gpu_info['performance_tier'] = 'Legacy'
            gpu_info['recommended_memory_gb'] = min(4, int(gpu_info['total_memory_gb'] * 0.4))
            
        return gpu_info
    
    def get_memory_info(self) -> Dict[str, Any]:
        """Get current memory usage with dynamic resource info"""
        memory = psutil.virtual_memory()
        device_config = self.device_detector.generate_config()
        
        return {
            "total_gb": memory.total / (1024**3),
            "available_gb": memory.available / (1024**3),
            "used_gb": memory.used / (1024**3),
            "percent_used": memory.percent,
            "device": self.device,
            "allocated_gb": self.max_memory_gb,
            "conservative_mode": self.use_conservative_settings,
            "other_apps_gb": sum(p.memory_mb for p in self.device_detector.other_processes) / 1024,
            "cpu_percent": device_config["system_info"]["cpu_percent"]
        }
    
    def get_model_path(self) -> Path:
        """Get the full path to the model"""
        platform_config = get_platform_config()
        model_name = platform_config.get("model_path", "llama-3.2-3b-quantized-q4km")
        script_dir = Path(__file__).parent
        return script_dir / model_name
        
    def detect_model_type(self, model_path: Path) -> str:
        """Detect if this is a GGUF model or PyTorch model"""
        if model_path.is_dir():
            # Check for GGUF file in directory
            gguf_files = list(model_path.glob("*.gguf"))
            if gguf_files:
                return "gguf"
            else:
                return "pytorch"
        elif model_path.suffix == ".gguf":
            return "gguf"
        else:
            return "pytorch"
    
    def optimize_memory(self):
        """Optimize memory allocation with dynamic resource management"""
        try:
            # Get current memory info
            memory_info = self.get_memory_info()
            device_config = self.device_detector.generate_config()
            
            print(f"🔧 Dynamic Memory Optimization:")
            print(f"   Current Usage: {memory_info['used_gb']:.1f}GB")
            print(f"   Available: {memory_info['available_gb']:.1f}GB")
            print(f"   Allocated: {self.max_memory_gb:.1f}GB")
            print(f"   Other Apps: {memory_info['other_apps_gb']:.1f}GB")
            
            # Enhanced MPS memory management with dynamic allocation
            if self.device == "mps":
                try:
                    import torch.mps
                    
                    # Get optimal memory fraction
                    memory_fraction = self.device_detector.resource_allocation.memory_fraction
                    print(f"✅ MPS memory fraction set to {memory_fraction*100:.1f}%")
                    
                    # Clear cache more aggressively
                    if hasattr(torch.mps, 'empty_cache'):
                        torch.mps.empty_cache()
                    
                    # Force garbage collection
                    gc.collect()
                    
                    # Set memory limits dynamically
                    if hasattr(torch.mps, 'set_per_process_memory_fraction'):
                        torch.mps.set_per_process_memory_fraction(memory_fraction)
                except ImportError:
                    print("⚠️ torch.mps not available for MPS optimization")
            
            # Standard memory optimization
            try:
                import torch
                if hasattr(torch, 'cuda') and torch.cuda.is_available():
                    torch.cuda.empty_cache()
            except ImportError:
                print("⚠️ torch not available for CUDA optimization")
            
            # Force garbage collection
            gc.collect()
            
            # Get memory info after optimization
            memory_after = self.get_memory_info()
            print(f"📊 Memory after optimization: {memory_after['used_gb']:.1f}GB used, {memory_after['available_gb']:.1f}GB available")
            
        except Exception as e:
            print(f"⚠️ Memory optimization failed: {e}")
    
    def load_model(self):
        """Load the model with dynamic resource management and GGUF support"""
        with self.load_lock:
            if self.is_loaded:
                return
            
            # Get model path and detect type
            model_path = self.get_model_path()
            if not model_path.exists():
                raise FileNotFoundError(f"Model not found: {model_path}")
            
            self.model_type = self.detect_model_type(model_path)
            print(f"🔍 Detected model type: {self.model_type}")
            print(f"📁 Model path: {model_path}")
            
            # Get platform-adaptive configuration
            platform_config = get_platform_config()
            
            print(f"🔄 Loading optimized model on {self.device} with dynamic resource allocation...")
            print(f"🖥️ Platform: {platform_config['platform']}")
            
            # Show current system state
            print(f"📊 System State:")
            print(f"   - Available memory: {self.device_detector.system_info.available_memory_gb:.1f}GB")
            print(f"   - Total memory: {self.device_detector.system_info.total_memory_gb:.1f}GB")
            print(f"   - CPU usage: {self.device_detector.system_info.cpu_percent:.1f}%")
            print(f"   - Other processes: {len(self.device_detector.other_processes)} ({(sum(p.memory_mb for p in self.device_detector.other_processes) / 1024):.1f}GB)")
            
            # Recalculate resource allocation before loading
            allocation_info = self.device_detector.resource_allocation
            self.max_memory_gb = allocation_info.recommended_memory_gb
            self.use_conservative_settings = allocation_info.use_conservative
            
            print(f"📊 Dynamic Allocation Strategy:")
            print(f"   - Recommended memory: {self.max_memory_gb:.1f}GB")
            print(f"   - Conservative mode: {self.use_conservative_settings}")
            print(f"   - Memory fraction: {allocation_info.memory_fraction:.1%}")
            print(f"   - Safety margin: {allocation_info.safety_margin_gb:.1f}GB")
            
            # Pre-optimize memory before loading
            self.optimize_memory()
            
            # Load model based on type
            try:
                if self.model_type == "gguf":
                    if LLAMA_CPP_AVAILABLE:
                        self._load_gguf_model(model_path)
                    else:
                        print("⚠️ llama-cpp-python not available - falling back to PyTorch")
                        # Try to find a PyTorch model as fallback
                        pytorch_path = Path(__file__).parent / "llama-3.2-3b-instruct"
                        if pytorch_path.exists():
                            self._load_pytorch_model(str(pytorch_path))
                            self.model_type = "pytorch"
                        else:
                            raise ImportError("llama-cpp-python not available and no PyTorch fallback found")
                else:
                    self._load_pytorch_model(str(model_path))
                    
                self.is_loaded = True
                print(f"✅ Model loaded successfully ({self.model_type})")
                
            except Exception as e:
                print(f"❌ Failed to load model: {e}")
                
                # If MPS fails, try CPU fallback for PyTorch models
                if self.model_type == "pytorch" and self.device == "mps":
                    print("🔄 MPS failed, attempting CPU fallback...")
                    self.device = "cpu"
                    self.max_memory_gb = min(8.0, self.device_detector.system_info.available_memory_gb * 0.6)
                    self.use_conservative_settings = True
                    
                    try:
                        self._load_pytorch_model(str(model_path))
                        self.is_loaded = True
                        print("✅ Successfully loaded model on CPU fallback")
                    except Exception as cpu_error:
                        print(f"❌ CPU fallback also failed: {cpu_error}")
                        raise RuntimeError(f"Model loading failed on both MPS and CPU: {e}")
                else:
                    raise
    
    def _load_gguf_model(self, model_path: Path):
        """Load GGUF model with dynamic resource management"""
        # Clear any existing model to free memory
        if hasattr(self, 'model') and self.model is not None:
            del self.model
            if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                torch.mps.empty_cache()
            gc.collect()
        
        # Find the GGUF file
        if model_path.is_dir():
            gguf_files = list(model_path.glob("*.gguf"))
            if not gguf_files:
                raise FileNotFoundError(f"No GGUF files found in {model_path}")
            gguf_file = gguf_files[0]  # Use the first GGUF file
        else:
            gguf_file = model_path
            
        print(f"🔄 Loading GGUF model: {gguf_file}")
        
        # Get platform info
        platform_config = get_platform_config()
        platform = platform_config.get("platform", "unknown")
        
        # Configure llama.cpp based on platform and resources
        llama_kwargs = {
            "model_path": str(gguf_file),
            "n_ctx": 2048,  # Context window
            "n_batch": 512,  # Batch size for prompt processing
            "verbose": False,
            "use_mmap": True,  # Memory mapping for efficiency
            "use_mlock": False,  # Don't lock memory
            "n_threads": None,  # Auto-detect threads
        }
        
        # Platform-specific optimizations
        if platform == "macos_apple_silicon":
            # Use dynamic batch size based on available memory
            available_memory = self.device_detector.system_info.available_memory_gb
            if available_memory > 8.0:
                batch_size = 1024
                gpu_layers = 1
            elif available_memory > 4.0:
                batch_size = 512
                gpu_layers = 1
            else:
                batch_size = 256
                gpu_layers = 0  # CPU only if low memory
            
            llama_kwargs.update({
                "n_gpu_layers": gpu_layers,
                "n_batch": batch_size,
                "use_mmap": True,
                "use_mlock": False,
            })
            print(f"🍎 Apple Silicon optimizations applied (GPU layers: {gpu_layers}, Batch: {batch_size})")
            
        elif "cuda" in platform:
            llama_kwargs.update({
                "n_gpu_layers": -1,  # Use all GPU layers
                "n_batch": 2048,     # Higher batch for CUDA
                "use_mmap": True,
            })
            print("🚀 CUDA optimizations applied")
            
        else:
            llama_kwargs.update({
                "n_gpu_layers": 0,   # CPU only
                "n_batch": 256,      # Lower batch for CPU
                "n_threads": psutil.cpu_count() // 2,  # Half CPU threads
            })
            print("💻 CPU optimizations applied")
        
        # Load the model
        self.model = Llama(**llama_kwargs)
        
        # For GGUF models, we don't need a separate tokenizer
        self.tokenizer = self.model
        
        print(f"✅ GGUF model loaded with {llama_kwargs.get('n_gpu_layers', 0)} GPU layers")
        
        # Final memory optimization
        self.optimize_memory()
        
        # Show final allocation summary
        final_memory_info = self.get_memory_info()
        print(f"📈 Final GGUF System State:")
        print(f"   - Current usage: {final_memory_info['used_gb']:.1f}GB")
        print(f"   - Available: {final_memory_info['available_gb']:.1f}GB")
        print(f"   - Device: {self.device}")
        print(f"   - Model type: GGUF")
    
    def _load_pytorch_model(self, model_path: str):
        """Load PyTorch model with dynamic resource management"""
        # Clear any existing model to free memory
        if hasattr(self, 'model') and self.model is not None:
            del self.model
            if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                torch.mps.empty_cache()
            gc.collect()
        
        print("📝 Loading optimized tokenizer...")
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_path,
            trust_remote_code=True,
            use_fast=True
        )
        
        # Set pad token if not present
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        
        print("🧠 Loading PyTorch model with dynamic resource optimizations...")
        
        # For MPS, use smarter memory management
        if self.device == "mps":
            print("🔧 Using smart MPS-optimized loading strategy...")
            
            # Calculate safe MPS allocation based on available system memory
            available_memory_gb = self.device_detector.system_info.available_memory_gb
            other_apps_gb = sum(p.memory_mb for p in self.device_detector.other_processes) / 1024
            
            # Conservative MPS allocation strategy
            mps_allocation_strategies = [
                {"mps_gb": 1.0, "cpu_gb": 3.0, "description": "Proven (1GB MPS)"},
                {"mps_gb": 1.5, "cpu_gb": 2.5, "description": "Moderate (1.5GB MPS)"},
                {"mps_gb": 2.0, "cpu_gb": 2.0, "description": "Aggressive (2GB MPS)"}
            ]
            
            # Choose strategy based on available memory
            if available_memory_gb > 8.0 and other_apps_gb < 3.0:
                strategy = mps_allocation_strategies[1]  # Moderate (1.5GB)
            elif available_memory_gb > 6.0 and other_apps_gb < 4.0:
                strategy = mps_allocation_strategies[0]  # Proven (1GB)
            else:
                strategy = mps_allocation_strategies[0]  # Proven (1GB)
            
            mps_allocation_gb = strategy["mps_gb"]
            cpu_allocation_gb = strategy["cpu_gb"]
            
            print(f"   Strategy: {strategy['description']}")
            print(f"   Available system memory: {available_memory_gb:.1f}GB")
            print(f"   Other apps: {other_apps_gb:.1f}GB")
            print(f"   MPS allocation: {mps_allocation_gb:.1f}GB")
            print(f"   CPU allocation: {cpu_allocation_gb:.1f}GB")
            
            model_kwargs = {
                "torch_dtype": torch.float16,
                "low_cpu_mem_usage": True,
                "attn_implementation": "eager",
                "device_map": "auto",
                "max_memory": {
                    0: f"{mps_allocation_gb:.1f}GB",  # MPS allocation
                    "cpu": f"{cpu_allocation_gb:.1f}GB"  # CPU allocation
                },
                "offload_folder": "offload",
                "offload_state_dict": True,
            }
            
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                **model_kwargs
            )
            
            print(f"✅ Successfully loaded with {strategy['description']}")
            
            # Clear cache after loading
            if hasattr(torch.mps, 'empty_cache'):
                torch.mps.empty_cache()
                
        elif self.device == "cpu":
            print("🔧 Using CPU-optimized loading strategy...")
            
            # For CPU, use more conservative settings
            cpu_allocation_gb = min(6.0, self.device_detector.system_info.available_memory_gb * 0.7)
            
            print(f"   CPU allocation: {cpu_allocation_gb:.1f}GB")
            print(f"   Available memory: {self.device_detector.system_info.available_memory_gb:.1f}GB")
            
            model_kwargs = {
                "torch_dtype": torch.float16,
                "low_cpu_mem_usage": True,
                "attn_implementation": "eager",
                "device_map": "cpu",
                "max_memory": {"cpu": f"{cpu_allocation_gb:.1f}GB"},
                "offload_folder": "offload",
                "offload_state_dict": True,
            }
            
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                **model_kwargs
            )
            
        else:
            # For other devices, use standard approach
            model_kwargs = {
                "torch_dtype": torch.float16,
                "low_cpu_mem_usage": True,
                "attn_implementation": "eager",
            }
            
            # Add device-specific optimizations
            if self.device != "cpu":
                model_kwargs["device_map"] = "auto"
                model_kwargs["max_memory"] = {0: f"{self.max_memory_gb}GB"}
                model_kwargs["offload_folder"] = "offload"
                model_kwargs["offload_state_dict"] = True
            
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                **model_kwargs
            )
        
        # Apply vLLM-style optimizations if available
        if VLLM_OPTIMIZATIONS_AVAILABLE and self.vllm_optimizer:
            print("🚀 Applying vLLM-style optimizations...")
            self.vllm_optimizer.optimize_memory()
        
        # Set model to evaluation mode
        self.model.eval()
        
        # Final memory optimization
        self.optimize_memory()
        
        print(f"✅ PyTorch model loaded successfully on {self.device} with {self.max_memory_gb:.1f}GB allocation")
        print(f"📊 Memory usage: {self.get_memory_info()['used_gb']:.1f}GB used")
        
        # Show final allocation summary
        final_memory_info = self.get_memory_info()
        print(f"📈 Final PyTorch System State:")
        print(f"   - Model allocated: {self.max_memory_gb:.1f}GB")
        print(f"   - Current usage: {final_memory_info['used_gb']:.1f}GB")
        print(f"   - Available: {final_memory_info['available_gb']:.1f}GB")
        print(f"   - Conservative mode: {self.use_conservative_settings}")
        print(f"   - Device: {self.device}")
    
    def format_chat_prompt(self, messages: List[Dict[str, str]]) -> str:
        """Format chat messages using reliable formatting"""
        try:
            # Use the reliable chat format that works consistently
            formatted = self._reliable_chat_format(messages)
            print(f"🔍 Debug - Using reliable format: {repr(formatted[:100])}...")
            return formatted
        except Exception as e:
            print(f"⚠️ Chat formatting error, using simple fallback: {e}")
            # Simple fallback
            user_message = next((msg.get('content', '') for msg in messages if msg.get('role') == 'user'), '')
            return f"User: {user_message}\nAssistant: "
    
    def _reliable_chat_format(self, messages: List[Dict[str, str]]) -> str:
        """Reliable chat formatting that works consistently"""
        # For multi-turn conversations, we'll use a simple but effective approach
        conversation = []
        
        for message in messages:
            role = message.get('role', 'user')
            content = message.get('content', '').strip()
            
            if not content:  # Skip empty messages
                continue
            
            if role == 'system':
                conversation.append(f"System: {content}")
            elif role == 'user':
                conversation.append(f"User: {content}")
            elif role == 'assistant':
                conversation.append(f"Assistant: {content}")
        
        # Join the conversation with newlines
        formatted_prompt = "\n".join(conversation)
        
        # Add the assistant prompt
        formatted_prompt += "\nAssistant: "
        
        return formatted_prompt
    
    def calculate_usage(self, prompt: str, response: str) -> Dict[str, int]:
        """Calculate token usage for OpenAI compatibility"""
        try:
            if self.model_type == "gguf":
                # For GGUF models, approximate token counts
                # GGUF models don't expose tokenizer directly, so we estimate
                prompt_tokens = len(prompt.split()) * 1.3  # Rough approximation
                response_tokens = len(response.split()) * 1.3
                prompt_tokens = int(prompt_tokens)
                response_tokens = int(response_tokens)
            else:
                # For PyTorch models, use the tokenizer
                prompt_tokens = len(self.tokenizer.encode(prompt))
                response_tokens = len(self.tokenizer.encode(response))
            
            total_tokens = prompt_tokens + response_tokens
            
            return {
                "prompt_tokens": prompt_tokens,
                "completion_tokens": response_tokens,
                "total_tokens": total_tokens
            }
        except Exception as e:
            print(f"⚠️ Error calculating usage: {e}")
            # Fallback to simple word count estimation
            prompt_tokens = len(prompt.split())
            response_tokens = len(response.split())
            return {
                "prompt_tokens": prompt_tokens,
                "completion_tokens": response_tokens,
                "total_tokens": prompt_tokens + response_tokens
            }
    
    def generate_stream(self, prompt: str, max_tokens: int = 100, temperature: float = 0.7, 
                       top_p: float = 0.9, repetition_penalty: float = 1.1, 
                       use_optimizations: bool = True) -> AsyncGenerator[str, None]:
        """Generate text with streaming, supporting both GGUF and PyTorch models"""
        if not self.is_loaded:
            self.load_model()
        
        # Pre-optimize for generation
        if use_optimizations:
            self.optimize_memory()
        
        try:
            if self.model_type == "gguf":
                # GGUF model generation using llama-cpp-python
                print(f"🔧 GGUF streaming generation: max_tokens={max_tokens}")
                
                # Generate with streaming
                response = self.model(
                    prompt,
                    max_tokens=max_tokens,
                    temperature=temperature,
                    top_p=top_p,
                    repeat_penalty=repetition_penalty,
                    stream=True,
                    echo=False
                )
                
                for chunk in response:
                    if 'choices' in chunk and len(chunk['choices']) > 0:
                        choice = chunk['choices'][0]
                        if 'text' in choice and choice['text']:
                            yield choice['text']
                            
            else:
                # PyTorch model generation
                print(f"🔧 PyTorch streaming generation: max_tokens={max_tokens}")
                
                # Tokenize with optimizations
                inputs = self.tokenizer(
                    prompt, 
                    return_tensors="pt",
                    truncation=True,
                    max_length=1024,  # Reduced for memory efficiency
                    padding=True
                )
                
                # Move to device
                if self.device != "cpu":
                    inputs = {k: v.to(self.device) for k, v in inputs.items()}
                
                # Calculate chunk size based on max_tokens
                chunk_size = min(512, max(64, max_tokens // 10))  # Adaptive chunking
                total_generated = 0
                
                # Generate with optimizations and chunking
                with torch.no_grad():
                    # Clear cache before generation
                    if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                        torch.mps.empty_cache()
                    
                    # Use streaming generation with chunking
                    for chunk_start in range(0, max_tokens, chunk_size):
                        chunk_tokens = min(chunk_size, max_tokens - chunk_start)
                        
                        if chunk_start == 0:
                            # First chunk - generate from prompt
                            outputs = self.model.generate(
                                **inputs,
                                max_new_tokens=chunk_tokens,
                                temperature=temperature,
                                top_p=top_p,
                                do_sample=True,
                                pad_token_id=self.tokenizer.eos_token_id,
                                use_cache=True,
                                repetition_penalty=repetition_penalty,
                                eos_token_id=self.tokenizer.eos_token_id,
                                return_dict_in_generate=True,
                                output_scores=False,
                                streamer=None  # We handle streaming manually
                            )
                        else:
                            # Subsequent chunks - continue from previous output
                            # Get the last generated tokens as input for next chunk
                            last_tokens = outputs.sequences[0][-chunk_size:] if hasattr(outputs, 'sequences') else []
                            if len(last_tokens) > 0:
                                chunk_inputs = {"input_ids": last_tokens.unsqueeze(0)}
                                if self.device != "cpu":
                                    chunk_inputs = {k: v.to(self.device) for k, v in chunk_inputs.items()}
                                
                                outputs = self.model.generate(
                                    **chunk_inputs,
                                    max_new_tokens=chunk_tokens,
                                    temperature=temperature,
                                    top_p=top_p,
                                    do_sample=True,
                                    pad_token_id=self.tokenizer.eos_token_id,
                                    use_cache=True,
                                    repetition_penalty=repetition_penalty,
                                    eos_token_id=self.tokenizer.eos_token_id,
                                    return_dict_in_generate=True,
                                    output_scores=False
                                )
                        
                        # Decode and yield the chunk
                        if hasattr(outputs, 'sequences'):
                            generated_tokens = outputs.sequences[0][-chunk_tokens:] if chunk_start > 0 else outputs.sequences[0]
                            chunk_text = self.tokenizer.decode(generated_tokens, skip_special_tokens=True)
                            
                            if chunk_text.strip():
                                total_generated += len(generated_tokens)
                                print(f"📦 Chunk {chunk_start//chunk_size + 1}: {len(generated_tokens)} tokens, total: {total_generated}")
                                yield chunk_text
                        
                        # Memory management between chunks
                        if use_optimizations:
                            self.optimize_memory()
                        
                        # Check if we've reached the limit
                        if total_generated >= max_tokens:
                            break
                            
        except Exception as e:
            print(f"❌ Streaming generation error: {e}")
            yield f"Error during generation: {str(e)}"
    
    def generate_non_stream(self, prompt: str, max_tokens: int = 100, temperature: float = 0.7, 
                           top_p: float = 0.9, repetition_penalty: float = 1.1,
                           use_optimizations: bool = True) -> Dict[str, Any]:
        """Generate text without streaming, supporting both GGUF and PyTorch models"""
        if not self.is_loaded:
            self.load_model()
        
        # Pre-optimize for generation
        if use_optimizations:
            self.optimize_memory()
        
        start_time = time.time()
        
        # Try multiple generation attempts with different parameters if needed
        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                # Adjust parameters for retry attempts
                current_temperature = temperature
                current_max_tokens = max_tokens
                
                if attempt > 0:
                    # Increase temperature and max_tokens for retry attempts
                    current_temperature = min(temperature * (1 + attempt * 0.2), 1.5)
                    current_max_tokens = min(max_tokens * (1 + attempt * 0.3), 200)
                    print(f"🔄 Retry attempt {attempt + 1} with temperature={current_temperature:.2f}, max_tokens={current_max_tokens}")
                
                if self.model_type == "gguf":
                    # GGUF model generation using llama-cpp-python
                    print(f"🔧 GGUF non-stream generation: max_tokens={current_max_tokens}")
                    
                    response_data = self.model(
                        prompt,
                        max_tokens=current_max_tokens,
                        temperature=current_temperature,
                        top_p=top_p,
                        repeat_penalty=repetition_penalty,
                        stream=False,
                        echo=False
                    )
                    
                    if 'choices' in response_data and len(response_data['choices']) > 0:
                        generated_text = response_data['choices'][0]['text']
                        tokens_generated = response_data.get('usage', {}).get('completion_tokens', len(generated_text.split()))
                    else:
                        generated_text = ""
                        tokens_generated = 0
                    
                    # For GGUF, the response is ready to use
                    response = generated_text.strip()
                        
                else:
                    # PyTorch model generation
                    print(f"🔧 PyTorch non-stream generation: max_tokens={current_max_tokens}")
                    
                    # Tokenize with optimizations
                    inputs = self.tokenizer(
                        prompt, 
                        return_tensors="pt",
                        truncation=True,
                        max_length=1024,  # Reduced from 2048 to save memory
                        padding=True
                    )
                    
                    # Move to device
                    if self.device != "cpu":
                        inputs = {k: v.to(self.device) for k, v in inputs.items()}
                    
                    # Generate with optimizations and memory management
                    with torch.no_grad():
                        # Clear cache before generation
                        if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                            torch.mps.empty_cache()
                        
                        outputs = self.model.generate(
                            **inputs,
                            max_new_tokens=current_max_tokens,
                            temperature=current_temperature,
                            top_p=top_p,
                            do_sample=True,
                            pad_token_id=self.tokenizer.eos_token_id,
                            use_cache=True,
                            repetition_penalty=repetition_penalty,
                            # Generation optimizations
                            num_beams=1,
                            length_penalty=1.0,
                            # Memory optimizations
                            return_dict_in_generate=False,
                            output_scores=False,
                            # Additional memory saving
                            eos_token_id=self.tokenizer.eos_token_id,
                        )
                    
                    # Clear cache after generation
                    if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                        torch.mps.empty_cache()
                    
                    # Decode response (only for PyTorch models)
                    response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
                    response = response[len(prompt):].strip()
                    tokens_generated = len(outputs[0]) - len(inputs['input_ids'][0])
                
                # Validate response
                if self._validate_response(response):
                    generation_time = time.time() - start_time
                    tokens_per_second = tokens_generated / generation_time if generation_time > 0 else 0
                    
                    return {
                        "response": response,
                        "generation_time": generation_time,
                        "tokens_generated": tokens_generated,
                        "tokens_per_second": tokens_per_second,
                        "memory_usage": self.get_memory_info(),
                        "attempts": attempt + 1
                    }
                else:
                    print(f"⚠️ Attempt {attempt + 1} produced invalid response, retrying...")
                    if attempt < max_attempts - 1:
                        time.sleep(0.5)  # Brief pause before retry
                        # Clear memory before retry
                        if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                            torch.mps.empty_cache()
                        gc.collect()
                        continue
                    else:
                        # Last attempt failed, return a fallback response
                        fallback_response = self._generate_fallback_response(prompt)
                        generation_time = time.time() - start_time
                        
                        return {
                            "response": fallback_response,
                            "generation_time": generation_time,
                            "tokens_generated": len(self.tokenizer.encode(fallback_response)),
                            "tokens_per_second": 0,
                            "memory_usage": self.get_memory_info(),
                            "attempts": max_attempts,
                            "fallback": True
                        }
                        
            except Exception as e:
                print(f"⚠️ Generation attempt {attempt + 1} failed: {e}")
                if attempt < max_attempts - 1:
                    time.sleep(0.5)
                    # Clear memory before retry
                    if self.device == "mps" and hasattr(torch.mps, 'empty_cache'):
                        torch.mps.empty_cache()
                    gc.collect()
                    continue
                else:
                    # All attempts failed, return error response
                    raise e
    
    def _validate_response(self, response: str) -> bool:
        """Validate that the response is meaningful and not empty"""
        if not response or len(response.strip()) < 1:
            return False
        
        # Check for problematic response patterns (only exact matches)
        problematic_responses = [
            "",
            "I am [Your Name]",
            "I will be happy to help you",
            "Whether it's a specific topic"
        ]
        
        response_stripped = response.strip()
        for pattern in problematic_responses:
            if pattern == response_stripped:
                print(f"⚠️ Detected exact problematic response: {pattern}")
                return False
        
        # Check if response is just special tokens
        if response_stripped in ['<|eot_id|>', '<|end_of_text|>']:
            return False
        
        # Allow short responses (like "4" for math questions)
        if len(response_stripped) >= 1:
            return True
        
        # Allow responses that contain the problematic pattern as part of a larger response
        # Only reject if the entire response is problematic
        return True
    
    def _generate_fallback_response(self, prompt: str) -> str:
        """Generate a fallback response when normal generation fails"""
        # Extract the last user message from the prompt
        lines = prompt.split('\n')
        user_messages = [line for line in lines if line.strip().startswith('User:')]
        
        if user_messages:
            last_user_message = user_messages[-1].replace('User:', '').strip()
            
            # Generate a simple, helpful response based on the user's message
            if 'hello' in last_user_message.lower() or 'hi' in last_user_message.lower():
                return "Hello! I'm here to help you. How can I assist you today?"
            elif '?' in last_user_message:
                return "I understand your question. Let me help you with that. Could you please provide more details?"
            else:
                return "I see what you're asking about. Let me provide you with a helpful response. What specific information are you looking for?"
        else:
            return "I'm here to help! Please let me know what you'd like assistance with."

    def _handle_resource_alert(self, alert):
        """Handle resource alerts with aggregation to reduce spam"""
        # Create alert key for aggregation
        alert_key = f"{alert.resource_type.value}_{alert.level.value}"
        
        # Record the alert
        alert_aggregator.record_alert(alert_key)
        
        # Only show alert if it's been long enough since last similar alert
        if alert_aggregator.should_show_alert(alert_key):
            print(f"\n{alert.message}")
            print(f"💡 Recommendation: {alert.recommendation}")
            
            # Get current performance tier
            performance_tier = self.resource_monitor.get_performance_tier()
            recommendations = self.resource_monitor.get_recommendations()
            
            print(f"📊 Performance Tier: {performance_tier['tier'].upper()}")
            print(f"📝 Description: {performance_tier['desc']}")
            
            if recommendations:
                print(f"💡 Optimization Tips:")
                for rec in recommendations:
                    print(f"   • {rec}")
            
            print()  # Empty line for readability
        
        # Show summary every minute if there are multiple alerts
        current_time = time.time()
        if (current_time - alert_aggregator.last_summary_time > alert_aggregator.summary_interval and 
            alert_aggregator.alert_counts):
            summary = alert_aggregator.get_summary()
            if summary:
                print(f"\n{summary}")
                print()  # Empty line for readability
            alert_aggregator.last_summary_time = current_time

    def _select_best_device(self) -> str:
        """Select the best available device with MPS priority"""
        devices = self._detect_all_devices()
        
        print("🔍 Dynamic Device Selection:")
        print(f"   Available Memory: {self.system_info['available_memory_gb']:.1f}GB")
        print(f"   Total Memory: {self.system_info['total_memory_gb']:.1f}GB")
        print(f"   CPU Usage: {self.system_info['cpu_percent']:.1f}%")
        print(f"   Other Processes: {self.system_info['other_processes_gb']:.1f}GB")
        
        # Priority order: MPS > CUDA > ROCm > CPU
        # But MPS needs sufficient memory
        if devices['mps']['supported']:
            mps_memory = devices['mps']['memory_gb']
            available_memory = self.system_info['available_memory_gb']
            
            # MPS priority: Use MPS if we have at least 2GB available (reduced from previous higher threshold)
            if available_memory >= 2.0:
                print(f"   ✅ MPS: {devices['mps']['device_name']} ({devices['mps']['performance_tier']})")
                print(f"   ✅ MPS: Sufficient memory ({available_memory:.1f}GB available)")
                return "mps"
            else:
                print(f"   ⚠️ MPS: {devices['mps']['device_name']} ({devices['mps']['performance_tier']})")
                print(f"   ⚠️ MPS: Low memory ({available_memory:.1f}GB available) - but will try anyway")
                # Force MPS usage even with low memory since it's much faster than CPU
                return "mps"
        
        if devices['cuda']['supported']:
            print(f"   ✅ CUDA: {devices['cuda']['device_name']} ({devices['cuda']['performance_tier']})")
            return "cuda"
            
        if devices['rocm']['supported']:
            print(f"   ✅ ROCm: {devices['rocm']['device_name']} ({devices['rocm']['performance_tier']})")
            return "rocm"
        
        # CPU fallback
        print(f"   ✅ CPU: {devices['cpu']['device_name']} ({devices['cpu']['performance_tier']})")
        print(f"   ✅ CPU: Always available as fallback")
        return "cpu"

# Initialize model
def init_model():
    global model_instance
    model_instance = OptimizedLlamaModel()
    model_instance.load_model()

# Global start time for uptime tracking
start_time = time.time()

# FastAPI app with lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 Starting Optimized Resource FastAPI Llama server...")
    init_model()
    
    # Global resource monitoring is already started by the model instance
    # No need to start it again here
    
    yield
    
    # Shutdown
    print("🛑 Shutting down optimized server...")
    stop_global_monitoring()

# Create FastAPI app
app = FastAPI(
    title="Optimized Resource Llama-3.2-3B FastAPI Server",
    description="High-performance FastAPI server with OpenAI compatibility and resource optimizations",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint with server information"""
    return {
        "message": "HuddleAI (HL) Server",
        "model": "HuddleAI",
        "base_model": "Llama 3.2 3B Instruct",
        "docs": "/docs",
        "health": "/health",
        "generate": "/generate",
        "generate/stream": "/generate/stream",
        "optimizations": "enabled",
        "version": "1.0.0",
        "description": "Optimized language model with platform-adaptive configuration"
    }

@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    memory_info = model_instance.get_memory_info() if model_instance else {}
    uptime = time.time() - start_time if 'start_time' in globals() else 0
    
    # Add resource monitoring info with device context
    if model_instance and hasattr(model_instance, 'resource_monitor'):
        performance_tier = model_instance.resource_monitor.get_performance_tier()
        recommendations = model_instance.resource_monitor.get_recommendations()
        device_metrics = model_instance.resource_monitor.get_device_aware_metrics()
        memory_info.update({
            "performance_tier": performance_tier,
            "recommendations": recommendations,
            "monitoring_active": model_instance.resource_monitor.monitoring,
            "device_metrics": device_metrics
        })
    
    return HealthResponse(
        status="healthy",
        model_loaded=model_instance.is_loaded if model_instance else False,
        device=model_instance.device if model_instance else "unknown",
        uptime=uptime,
        memory_usage=memory_info
    )

@app.get("/health/pretty")
async def health_pretty():
    """Human-readable health check endpoint"""
    memory_info = model_instance.get_memory_info() if model_instance else {}
    uptime = time.time() - start_time if 'start_time' in globals() else 0
    uptime_hours = uptime / 3600
    
    # Get performance tier info
    performance_tier = {}
    recommendations = []
    if model_instance and hasattr(model_instance, 'resource_monitor'):
        performance_tier = model_instance.resource_monitor.get_performance_tier()
        recommendations = model_instance.resource_monitor.get_recommendations()
    
    # Format uptime
    hours = int(uptime_hours)
    minutes = int((uptime_hours % 1) * 60)
    uptime_str = f"{hours}h {minutes}m" if hours > 0 else f"{minutes}m"
    
    # Format memory usage
    total_gb = memory_info.get('total_gb', 0)
    available_gb = memory_info.get('available_gb', 0)
    used_percent = memory_info.get('percent_used', 0)
    
    # Performance tier emoji and status
    tier = performance_tier.get('tier', 'unknown')
    tier_emojis = {
        'optimal': '🟢',
        'good': '🟡',
        'warning': '🟠',
        'critical': '🔴'
    }
    tier_emoji = tier_emojis.get(tier, '⚪')
    
    # Device info
    device = model_instance.device if model_instance else "unknown"
    device_emojis = {
        'mps': '🍎',
        'cuda': '🚀',
        'cpu': '💻'
    }
    device_emoji = device_emojis.get(device, '💻')
    
    status_text = f"""
🤖 HuddleAI Server Status
═══════════════════════════

📊 Overall Status: {'✅ Healthy' if model_instance and model_instance.is_loaded else '❌ Not Ready'}
⏱️  Uptime: {uptime_str}
{device_emoji} Device: {device.upper()}
{tier_emoji} Performance: {tier.title()} ({performance_tier.get('desc', 'Unknown')})

💾 Memory Usage:
   Total: {total_gb:.1f} GB
   Available: {available_gb:.1f} GB
   Used: {used_percent:.1f}%

🔧 Recommendations:
{chr(10).join(f'   • {rec}' for rec in recommendations) if recommendations else '   • System running optimally'}

🌐 Endpoints:
   • Chat: POST /v1/chat/completions
   • Completions: POST /v1/completions  
   • Health (JSON): GET /health
   • Health (Pretty): GET /health/pretty
"""
    
    return {"content": status_text.strip(), "content_type": "text/plain"}

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(request: ChatCompletionRequest):
    """OpenAI-compatible chat completion endpoint with enhanced reliability"""
    try:
        if not model_instance or not model_instance.is_loaded:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Convert messages to format expected by the model
        messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]
        
        # Validate input messages
        if not messages:
            raise HTTPException(status_code=400, detail="No messages provided")
        
        # Check for empty messages
        for msg in messages:
            if not msg.get('content', '').strip():
                raise HTTPException(status_code=400, detail="Empty message content not allowed")
        
        # Format chat prompt - use reliable format
        prompt = model_instance.format_chat_prompt(messages)
        print(f"🔍 Debug - Final prompt: {repr(prompt[:100])}...")
        
        # Generate response with enhanced reliability
        result = model_instance.generate_non_stream(
            prompt=prompt,
            max_tokens=request.max_tokens or 100,
            temperature=request.temperature or 0.7,
            top_p=request.top_p or 0.9,
            repetition_penalty=1.1,  # Convert frequency_penalty to repetition_penalty
            use_optimizations=True
        )
        
        response_text = result["response"]
        
        # Additional validation for the response
        if not response_text or len(response_text.strip()) < 3:
            print("⚠️ Generated response is too short, using fallback")
            response_text = model_instance._generate_fallback_response(prompt)
        
        # Calculate usage
        usage = model_instance.calculate_usage(prompt, response_text)
        
        # Log generation details
        attempts = result.get("attempts", 1)
        fallback = result.get("fallback", False)
        if attempts > 1 or fallback:
            print(f"📊 Generation completed in {attempts} attempts, fallback: {fallback}")
        
        # Create OpenAI-compatible response
        return ChatCompletionResponse(
            id=f"chatcmpl-{int(time.time())}",
            created=int(time.time()),
            model=request.model,
            choices=[
                ChatCompletionChoice(
                    index=0,
                    message=ChatMessage(role="assistant", content=response_text),
                    finish_reason="stop"
                )
            ],
            usage=usage
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Chat completion error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat completion failed: {str(e)}")

@app.post("/v1/chat/completions")
async def chat_completions_stream(request: ChatCompletionRequest):
    """OpenAI-compatible streaming chat completion endpoint"""
    if not request.stream:
        return await chat_completions(request)
    
    try:
        if not model_instance or not model_instance.is_loaded:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Convert messages to format expected by the model
        messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]
        
        # Format chat prompt - use reliable format
        prompt = model_instance.format_chat_prompt(messages)
        print(f"🔍 Debug - Final prompt: {repr(prompt[:100])}...")
        
        async def generate_stream():
            response_id = f"chatcmpl-{int(time.time())}"
            created_time = int(time.time())
            
            # Send initial response
            yield f"data: {json.dumps({'id': response_id, 'object': 'chat.completion.chunk', 'created': created_time, 'model': request.model, 'choices': [{'index': 0, 'delta': {'role': 'assistant'}, 'finish_reason': None}]})}\n\n"
            
            # Stream tokens
            full_response = ""
            async for chunk in model_instance.generate_stream(
                prompt=prompt,
                max_tokens=request.max_tokens or 100,
                temperature=request.temperature or 0.7,
                top_p=request.top_p or 0.9,
                repetition_penalty=1.1,
                use_optimizations=True
            ):
                # Parse the chunk
                if chunk.startswith("data: "):
                    chunk_data = json.loads(chunk[6:])
                    token = chunk_data.get("token", "")
                    finished = chunk_data.get("finished", False)
                    
                    full_response += token
                    
                    # Send token chunk
                    yield f"data: {json.dumps({'id': response_id, 'object': 'chat.completion.chunk', 'created': created_time, 'model': request.model, 'choices': [{'index': 0, 'delta': {'content': token}, 'finish_reason': 'stop' if finished else None}]})}\n\n"
            
            # Send final chunk
            yield f"data: {json.dumps({'id': response_id, 'object': 'chat.completion.chunk', 'created': created_time, 'model': request.model, 'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'stop'}]})}\n\n"
            yield "data: [DONE]\n\n"
        
        return StreamingResponse(
            generate_stream(),
            media_type="text/plain",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "Content-Type": "text/event-stream"
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Streaming chat completion failed: {str(e)}")

@app.post("/v1/completions", response_model=CompletionResponse)
async def completions(request: CompletionRequest):
    """OpenAI-compatible text completion endpoint"""
    try:
        if not model_instance or not model_instance.is_loaded:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Generate response
        result = model_instance.generate_non_stream(
            prompt=request.prompt,
            max_tokens=request.max_tokens or 100,
            temperature=request.temperature or 0.7,
            top_p=request.top_p or 0.9,
            repetition_penalty=1.1,
            use_optimizations=True
        )
        
        response_text = result["response"]
        
        # Calculate usage
        usage = model_instance.calculate_usage(request.prompt, response_text)
        
        # Create OpenAI-compatible response
        return CompletionResponse(
            id=f"cmpl-{int(time.time())}",
            created=int(time.time()),
            model=request.model,
            choices=[
                CompletionChoice(
                    index=0,
                    text=response_text,
                    finish_reason="stop"
                )
            ],
            usage=usage
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Completion failed: {str(e)}")

@app.post("/v1/completions")
async def completions_stream(request: CompletionRequest):
    """OpenAI-compatible streaming text completion endpoint"""
    if not request.stream:
        return await completions(request)
    
    try:
        if not model_instance or not model_instance.is_loaded:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        async def generate_stream():
            response_id = f"cmpl-{int(time.time())}"
            created_time = int(time.time())
            
            # Stream tokens
            full_response = ""
            async for chunk in model_instance.generate_stream(
                prompt=request.prompt,
                max_tokens=request.max_tokens or 100,
                temperature=request.temperature or 0.7,
                top_p=request.top_p or 0.9,
                repetition_penalty=1.1,
                use_optimizations=True
            ):
                # Parse the chunk
                if chunk.startswith("data: "):
                    chunk_data = json.loads(chunk[6:])
                    token = chunk_data.get("token", "")
                    finished = chunk_data.get("finished", False)
                    
                    full_response += token
                    
                    # Send token chunk
                    yield f"data: {json.dumps({'id': response_id, 'object': 'text_completion.chunk', 'created': created_time, 'model': request.model, 'choices': [{'index': 0, 'text': token, 'finish_reason': 'stop' if finished else None}]})}\n\n"
            
            # Send final chunk
            yield f"data: {json.dumps({'id': response_id, 'object': 'text_completion.chunk', 'created': created_time, 'model': request.model, 'choices': [{'index': 0, 'text': '', 'finish_reason': 'stop'}]})}\n\n"
            yield "data: [DONE]\n\n"
        
        return StreamingResponse(
            generate_stream(),
            media_type="text/plain",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "Content-Type": "text/event-stream"
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Streaming completion failed: {str(e)}")

# Legacy endpoints (for backward compatibility)
@app.post("/generate/stream")
async def generate_stream(request: GenerateRequest):
    """Generate text with streaming response"""
    try:
        if not model_instance or not model_instance.is_loaded:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        if request.stream:
            async def generate_stream():
                try:
                    async for chunk in model_instance.generate_stream(
                        prompt=request.prompt,
                        max_tokens=request.max_tokens,
                        temperature=request.temperature,
                        top_p=request.top_p,
                        repetition_penalty=request.repetition_penalty,
                        use_optimizations=request.use_optimizations
                    ):
                        yield chunk
                except Exception as e:
                    print(f"⚠️ Streaming error: {e}")
                    # Send error chunk
                    error_chunk = {
                        "token": f"Error: {str(e)}",
                        "token_id": -1,
                        "finished": True,
                        "error": True
                    }
                    yield f"data: {json.dumps(error_chunk)}\n\n"
            
            return StreamingResponse(
                generate_stream(),
                media_type="text/plain",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "Content-Type": "text/event-stream",
                    "X-Accel-Buffering": "no"  # Disable nginx buffering
                }
            )
        else:
            # Non-streaming response
            result = model_instance.generate_non_stream(
                prompt=request.prompt,
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                repetition_penalty=request.repetition_penalty,
                use_optimizations=request.use_optimizations
            )
            
            return result
            
    except Exception as e:
        print(f"❌ Generate stream error: {e}")
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

@app.post("/generate")
async def generate_text(request: GenerateRequest):
    """Generate text without streaming with optimizations"""
    try:
        result = model_instance.generate_non_stream(
            prompt=request.prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
            repetition_penalty=request.repetition_penalty,
            use_optimizations=request.use_optimizations
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

@app.get("/model/info")
async def model_info():
    """Get model and resource information"""
    memory_info = model_instance.get_memory_info() if model_instance else {}
    device_config = model_instance.device_detector.generate_config() if model_instance else {}
    
    return {
        "model_name": "HuddleAI",
        "model_description": "HuddleAI - Optimized language model based on Llama 3.2 3B Instruct",
        "base_model": "llama-3.2-3b-quantized-q4km",
        "version": "1.0.0",
        "model_loaded": model_instance.is_loaded if model_instance else False,
        "device": model_instance.device if model_instance else "unknown",
        "device_info": device_config.get("device_info", {}),
        "system_info": device_config.get("system_info", {}),
        "resource_allocation": device_config.get("resource_allocation", {}),
        "memory_usage": memory_info,
        "performance_optimizations": {
            "vllm_optimizations": VLLM_OPTIMIZATIONS_AVAILABLE,
            "mixed_precision": model_instance.use_mixed_precision if model_instance else False,
            "conservative_mode": model_instance.use_conservative_settings if model_instance else False,
            "batch_size": model_instance.batch_size if model_instance else 1,
            "attention_heads": model_instance.num_attention_heads if model_instance else 16,
            "hidden_size": model_instance.hidden_size if model_instance else 2048
        },
        "model_capabilities": {
            "max_tokens": 32000,
            "supported_languages": ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Russian", "Chinese", "Japanese", "Korean"],
            "context_window": 8192,
            "optimization_level": "high",
            "platform_adaptive": True
        },
        "recommendations": device_config.get("recommendations", []),
        "other_processes": device_config.get("other_processes", [])
    }

@app.post("/optimize")
async def optimize_resources():
    """Manually trigger resource optimization"""
    if model_instance:
        model_instance.optimize_memory()
        return {"message": "Resources optimized", "memory": model_instance.get_memory_info()}
    else:
        raise HTTPException(status_code=500, detail="Model not loaded")

@app.post("/conversations/start")
async def start_conversation():
    """Start a new conversation session"""
    session_id = f"conv_{int(time.time())}"
    conversation_sessions[session_id] = {
        "messages": [],
        "created": time.time(),
        "last_activity": time.time()
    }
    return {"session_id": session_id, "status": "started"}

@app.get("/conversations/{session_id}")
async def get_conversation(session_id: str):
    """Get conversation history"""
    if session_id not in conversation_sessions:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    session = conversation_sessions[session_id]
    session["last_activity"] = time.time()
    
    return {
        "session_id": session_id,
        "messages": session["messages"],
        "created": session["created"],
        "last_activity": session["last_activity"]
    }

@app.delete("/conversations/{session_id}")
async def delete_conversation(session_id: str):
    """Delete a conversation session"""
    if session_id not in conversation_sessions:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    del conversation_sessions[session_id]
    return {"status": "deleted"}

@app.get("/conversations")
async def list_conversations():
    """List all active conversations"""
    return {
        "conversations": [
            {
                "session_id": session_id,
                "message_count": len(session["messages"]),
                "created": session["created"],
                "last_activity": session["last_activity"]
            }
            for session_id, session in conversation_sessions.items()
        ]
    }

@app.post("/v1/generate/vllm")
async def generate_vllm_style(request: GenerateRequest):
    """Generate text using vLLM-style optimizations"""
    try:
        result = model_instance.generate_vllm_style(
            prompt=request.prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
            repetition_penalty=request.repetition_penalty
        )
        print(f"[DEBUG] type(result): {type(result)}")
        if isinstance(result, dict) and "text" in result:
            print(f"[DEBUG] type(result['text']): {type(result['text'])}")
        else:
            print(f"[DEBUG] result: {result}")
        return {
            "success": True,
            "text": result["text"],
            "tokens_generated": result["tokens_generated"],
            "generation_time": result["generation_time"],
            "tokens_per_second": result["tokens_per_second"],
            "memory_usage": result["memory_usage"],
            "optimizations": "vLLM-style"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation error: {str(e)}")

@app.get("/v1/stats/vllm")
async def get_vllm_stats():
    """Get vLLM-style optimization statistics"""
    try:
        stats = model_instance.get_vllm_stats()
        return {
            "success": True,
            "stats": stats,
            "optimizations_available": VLLM_OPTIMIZATIONS_AVAILABLE
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats error: {str(e)}")

@app.get("/v1/resources/status")
async def get_resource_status():
    """Get current resource status and performance recommendations"""
    try:
        if not model_instance:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Get resource monitor status with device context
        performance_tier = model_instance.resource_monitor.get_performance_tier()
        recommendations = model_instance.resource_monitor.get_recommendations()
        current_metrics = model_instance.resource_monitor.get_device_aware_metrics()
        
        # Get device detector info
        device_config = model_instance.device_detector.generate_config()
        
        return {
            "success": True,
            "performance_tier": performance_tier,
            "recommendations": recommendations,
            "current_metrics": current_metrics,
            "device_info": device_config.get("device_info", {}),
            "resource_allocation": device_config.get("resource_allocation", {}),
            "system_info": device_config.get("system_info", {}),
            "monitoring_active": model_instance.resource_monitor.monitoring,
            "device_aware": True  # Indicate enhanced monitoring
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Resource status error: {str(e)}")

@app.post("/v1/resources/optimize")
async def optimize_resources_manual():
    """Manually trigger resource optimization and get recommendations"""
    try:
        if not model_instance:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Trigger optimization
        model_instance.optimize_memory()
        
        # Get updated status
        performance_tier = model_instance.resource_monitor.get_performance_tier()
        recommendations = model_instance.resource_monitor.get_recommendations()
        current_metrics = model_instance.resource_monitor.get_current_metrics()
        
        return {
            "success": True,
            "message": "Resources optimized",
            "performance_tier": performance_tier,
            "recommendations": recommendations,
            "current_metrics": current_metrics,
            "memory_usage": model_instance.get_memory_info()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Optimization error: {str(e)}")

@app.get("/v1/resources/debug")
async def get_resource_debug():
    """Get debug information about resource monitoring thresholds"""
    try:
        if not model_instance:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Get current thresholds
        thresholds = model_instance.resource_monitor.get_current_thresholds()
        current_metrics = model_instance.resource_monitor.get_current_metrics()
        device_config = model_instance.device_detector.generate_config()
        
        return {
            "success": True,
            "current_thresholds": thresholds,
            "current_metrics": current_metrics,
            "device_info": {
                "best_device": model_instance.device_detector.best_device,
                "device_name": device_config.get("device_info", {}).get("device_name", "Unknown"),
                "performance_tier": device_config.get("device_info", {}).get("performance_tier", "Unknown")
            },
            "resource_allocation": device_config.get("resource_allocation", {}),
            "monitoring_active": model_instance.resource_monitor.monitoring
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Debug info error: {str(e)}")

if __name__ == "__main__":
    print("🚀 Starting HuddleAI FastAPI Server...")
    print("🤖 Model: HuddleAI (based on Llama 3.2 3B Instruct)")
    print("📖 API Documentation: http://localhost:8002/docs")
    print("🔍 Alternative docs: http://localhost:8002/redoc")
    print("💚 Health check: http://localhost:8002/health")
    print("🌊 Streaming endpoint: http://localhost:8002/generate/stream")
    print("🔧 Optimize endpoint: http://localhost:8002/optimize")
    print("")
    print("🤖 OpenAI-Compatible Endpoints:")
    print("   💬 Chat Completions: http://localhost:8002/v1/chat/completions")
    print("   📝 Text Completions: http://localhost:8002/v1/completions")
    print("   🔄 Both support streaming with stream=true parameter")
    print("")
    print("📊 Resource Monitoring Endpoints:")
    print("   📈 Resource Status: GET http://localhost:8002/v1/resources/status")
    print("   🔧 Manual Optimize: POST http://localhost:8002/v1/resources/optimize")
    print("   💚 Health Check: GET http://localhost:8002/health (includes resource info)")
    print("")
    print("💬 Multi-Turn Chat Management:")
    print("   🆕 Start Conversation: POST http://localhost:8002/conversations/start")
    print("   📋 List Conversations: GET http://localhost:8002/conversations")
    print("   📖 Get Conversation: GET http://localhost:8002/conversations/{session_id}")
    print("   🗑️ Delete Conversation: DELETE http://localhost:8002/conversations/{session_id}")
    print("")
    print("🔍 Resource Monitoring Features:")
    print("   • Real-time resource monitoring (every 10 seconds)")
    print("   • Performance tier assessment (optimal → critical)")
    print("   • Automatic alerts for low resources")
    print("   • User-friendly optimization recommendations")
    print("   • Console warnings for developers")
    print("")
    print("📋 Example Resource Status Check:")
    print("   curl -X GET http://localhost:8002/v1/resources/status")
    print("")
    print("📋 Example Multi-Turn Chat:")
    print("   # Start conversation")
    print("   curl -X POST http://localhost:8002/conversations/start")
    print("")
    print("   # Send message with context")
    print("   curl -X POST http://localhost:8002/v1/chat/completions \\")
    print("     -H 'Content-Type: application/json' \\")
    print("     -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}, {\"role\": \"assistant\", \"content\": \"Hi there!\"}, {\"role\": \"user\", \"content\": \"How are you?\"}], \"stream\": false}'")
    
    uvicorn.run(
        "optimized_resource_server:app",
        host="0.0.0.0",
        port=8002,
        reload=False,
        workers=1,
        log_level="info"
    )