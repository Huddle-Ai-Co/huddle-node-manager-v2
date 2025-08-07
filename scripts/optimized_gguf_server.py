#!/usr/bin/env python3
"""
Optimized GGUF Resource Server
Supports both GGUF models (via llama.cpp) and PyTorch models for maximum performance
"""

import os
import sys
import time
import json
import psutil
import gc
import subprocess
from typing import Optional, Dict, Any, AsyncGenerator, List
import asyncio
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import uvicorn
import threading
from contextlib import asynccontextmanager
from pathlib import Path

# Add parent directory to sys.path for imports
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))
sys.path.insert(0, str(current_dir))

# Try importing llama-cpp-python for GGUF support
try:
    from llama_cpp import Llama
    LLAMA_CPP_AVAILABLE = True
    print("✅ llama-cpp-python available for GGUF models")
except ImportError:
    LLAMA_CPP_AVAILABLE = False
    print("⚠️ llama-cpp-python not available - GGUF models disabled")

# Try importing transformers for PyTorch fallback
try:
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    TORCH_AVAILABLE = True
    print("✅ PyTorch/transformers available for fallback")
except ImportError:
    TORCH_AVAILABLE = False
    print("⚠️ PyTorch/transformers not available")

# Import platform-adaptive configuration
from platform_adaptive_config import get_platform_config

# Import function calling tools (with fallback)
try:
    from function_tools import function_tools
    FUNCTION_TOOLS_AVAILABLE = True
    print("✅ Function tools imported successfully")
except ImportError as e:
    print(f"⚠️ Function tools not available: {e}")
    FUNCTION_TOOLS_AVAILABLE = False
    function_tools = None

try:
    from function_validation import function_detector, function_validator
    FUNCTION_VALIDATION_AVAILABLE = True
    print("✅ Function validation imported successfully")
except ImportError as e:
    print(f"⚠️ Function validation not available: {e}")
    FUNCTION_VALIDATION_AVAILABLE = False
    function_detector = None
    function_validator = None

# Import natural language processor (with fallback)
try:
    from natural_language_processor import nlp_processor
    NLP_PROCESSOR_AVAILABLE = True
    print("✅ NLP processor imported successfully")
except ImportError as e:
    print(f"⚠️ NLP processor not available: {e}")
    NLP_PROCESSOR_AVAILABLE = False
    nlp_processor = None

# Import web search confirmation system (with fallback)
try:
    from web_search_confirmation import WebSearchConfirmationSystem
    WEB_SEARCH_CONFIRMATION_AVAILABLE = True
    print("✅ Web search confirmation imported successfully")
except ImportError as e:
    print(f"⚠️ Web search confirmation not available: {e}")
    WEB_SEARCH_CONFIRMATION_AVAILABLE = False
    WebSearchConfirmationSystem = None

# Request/Response models (same as before)
class ChatMessage(BaseModel):
    role: str = Field(..., description="Role of the message sender (system, user, assistant)")
    content: Optional[str] = Field(default=None, description="Content of the message")
    
    def get(self, key, default=None):
        """Get attribute by key, similar to dictionary access"""
        return getattr(self, key, default)
    tool_calls: Optional[List[Dict[str, Any]]] = Field(default=None, description="Tool calls made by assistant")
    tool_call_id: Optional[str] = Field(default=None, description="ID of the tool call this message responds to")

class FunctionCall(BaseModel):
    name: str = Field(..., description="Function name")
    arguments: str = Field(..., description="Function arguments as JSON string")

class ToolCall(BaseModel):
    id: str = Field(..., description="Tool call ID")
    type: str = Field(default="function", description="Type of tool call")
    function: FunctionCall = Field(..., description="Function call details")

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
    tools: Optional[List[Dict[str, Any]]] = Field(default=None, description="Available tools")
    tool_choice: Optional[str] = Field(default="auto", description="Tool choice strategy")

class HealthResponse(BaseModel):
    status: str = Field(..., description="Server status")
    model_loaded: bool = Field(..., description="Whether model is loaded")
    model_type: str = Field(..., description="Model type (gguf/pytorch)")
    device: str = Field(..., description="Device being used")
    model_size: str = Field(..., description="Model size on disk")
    uptime: float = Field(..., description="Server uptime in seconds")
    memory_usage: Dict[str, Any] = Field(..., description="Memory usage information")

class OptimizedModelManager:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_type = None  # "gguf" or "pytorch"
        self.model_path = None
        self.is_loaded = False
        self.load_lock = threading.Lock()
        
        # Get platform configuration
        self.config = get_platform_config()
        self.platform = self.config.get("platform", "unknown")
        print(f"🔧 Platform detected: {self.platform}")
        
        # Apply environment variable overrides
        self.apply_env_overrides()
        
        # Initialize web search confirmation system (if available)
        if WEB_SEARCH_CONFIRMATION_AVAILABLE and WebSearchConfirmationSystem:
            self.confirmation_system = WebSearchConfirmationSystem()
        else:
            self.confirmation_system = None
            
    def apply_env_overrides(self):
        """Apply environment variable overrides to configuration"""
        # Check for environment variables and override config
        env_overrides = {
            "HUDDLE_MODEL_TYPE": "model_type",
            "HUDDLE_DEVICE": "device",
            "HUDDLE_BATCH_SIZE": "batch_size",
            "HUDDLE_MAX_CONCURRENT": "max_concurrent_requests",
            "HUDDLE_MEMORY_FRACTION": "memory_fraction",
            "HUDDLE_ATTENTION_IMPL": "attention_implementation",
            "HUDDLE_N_GPU_LAYERS": "n_gpu_layers",
            "HUDDLE_N_CTX": "n_ctx",
            "HUDDLE_N_BATCH": "n_batch",
            "HUDDLE_N_THREADS": "n_threads"
        }
        
        # Apply overrides if they exist in environment
        for env_var, config_key in env_overrides.items():
            if env_var in os.environ:
                value = os.environ[env_var]
                
                # Convert to appropriate type
                if config_key in ["batch_size", "max_concurrent_requests", "n_gpu_layers", "n_ctx", "n_batch", "n_threads"]:
                    try:
                        value = int(value)
                    except ValueError:
                        print(f"⚠️ Invalid value for {env_var}: {value}. Must be an integer.")
                        continue
                elif config_key in ["memory_fraction"]:
                    try:
                        value = float(value)
                    except ValueError:
                        print(f"⚠️ Invalid value for {env_var}: {value}. Must be a float.")
                        continue
                
                # Update config
                self.config[config_key] = value
                print(f"🔧 Override from environment: {config_key} = {value}")
                
        # Special handling for loading_config
        loading_config_keys = ["n_ctx", "n_batch", "n_threads", "n_gpu_layers"]
        loading_config = self.config.get("loading_config", {})
        
        for key in loading_config_keys:
            if key in self.config:
                loading_config[key] = self.config[key]
                
        self.config["loading_config"] = loading_config
        
    def get_model_path(self) -> Path:
        """Get the full path to the model"""
        # Check for environment variable override
        env_model_path = os.environ.get("HUDDLE_MODEL_PATH")
        
        if env_model_path:
            # If absolute path is provided
            if os.path.isabs(env_model_path):
                model_path = Path(env_model_path)
            else:
                # If relative path, resolve from script directory
                script_dir = Path(__file__).parent
                model_path = script_dir / env_model_path
            
            print(f"🔧 Using model path from environment: {model_path}")
            return model_path
            
        # Otherwise use config-based path
        model_name = self.config.get("model_path", "llama-3.2-3b-quantized-q4km")
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
    
    def load_model(self):
        """Load the appropriate model type"""
        with self.load_lock:
            if self.is_loaded:
                return
                
            model_path = self.get_model_path()
            if not model_path.exists():
                raise FileNotFoundError(f"Model not found: {model_path}")
            
            self.model_type = self.detect_model_type(model_path)
            print(f"🔍 Detected model type: {self.model_type}")
            print(f"📁 Model path: {model_path}")
            
            if self.model_type == "gguf":
                if LLAMA_CPP_AVAILABLE:
                    self._load_gguf_model(model_path)
                else:
                    print("⚠️ llama-cpp-python not available - falling back to PyTorch model")
                    # Fall back to original PyTorch model directory
                    fallback_path = Path(__file__).parent / "llama-3.2-3b-quantized-q4km"
                    print(f"🔄 Using PyTorch fallback model: {fallback_path}")
                    self._load_pytorch_model(fallback_path)
                    self.model_type = "pytorch"  # Update type to reflect actual loading method
            else:
                self._load_pytorch_model(model_path)
                
            self.model_path = model_path
            self.is_loaded = True
            print(f"✅ Model loaded successfully ({self.model_type})")
    
    def _load_gguf_model(self, model_path: Path):
        """Load GGUF model using llama.cpp with config-based parameters"""
        # llama-cpp-python availability is checked before calling this method
        
        # Find the GGUF file
        if model_path.is_dir():
            gguf_files = list(model_path.glob("*.gguf"))
            if not gguf_files:
                raise FileNotFoundError(f"No GGUF files found in {model_path}")
            gguf_file = gguf_files[0]  # Use the first GGUF file
        else:
            gguf_file = model_path
            
        print(f"🔄 Loading GGUF model: {gguf_file}")
        
        # Load model config
        config_path = model_path / "model_config.json" if model_path.is_dir() else model_path.parent / "model_config.json"
        model_config = {}
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    model_config = json.load(f)
                print(f"📋 Loaded model config: {model_config.get('model_name', 'unknown')}")
            except Exception as e:
                print(f"⚠️ Failed to load model config: {e}")
        
        # Get loading config with defaults
        loading_config = model_config.get("loading_config", {})
        
        # Apply environment variable overrides to loading_config
        for key in ["n_ctx", "n_batch", "n_threads", "n_gpu_layers"]:
            env_key = f"HUDDLE_{key.upper()}"
            if env_key in os.environ:
                try:
                    loading_config[key] = int(os.environ[env_key])
                    print(f"🔧 Override from environment: {key} = {loading_config[key]}")
                except ValueError:
                    print(f"⚠️ Invalid value for {env_key}: {os.environ[env_key]}. Must be an integer.")
        
        # Configure llama.cpp with config parameters
        llama_kwargs = {
            "model_path": str(gguf_file),
            "n_ctx": loading_config.get("n_ctx", 8192),
            "n_batch": loading_config.get("n_batch", 512),
            "verbose": loading_config.get("verbose", False),
            "use_mmap": loading_config.get("use_mmap", True),
            "use_mlock": loading_config.get("use_mlock", False),
            "n_threads": loading_config.get("n_threads", None),
            "f16_kv": loading_config.get("f16_kv", True),
        }
        
        # Platform-specific overrides (only if not specified in config or env)
        if "n_gpu_layers" not in loading_config:
            # Check for environment variable override
            if "HUDDLE_N_GPU_LAYERS" in os.environ:
                try:
                    llama_kwargs["n_gpu_layers"] = int(os.environ["HUDDLE_N_GPU_LAYERS"])
                    print(f"🔧 Using GPU layers from environment: {llama_kwargs['n_gpu_layers']}")
                except ValueError:
                    print(f"⚠️ Invalid value for HUDDLE_N_GPU_LAYERS: {os.environ['HUDDLE_N_GPU_LAYERS']}. Using platform default.")
                    if self.platform == "macos_apple_silicon":
                        llama_kwargs["n_gpu_layers"] = 1
                        print("🍎 Apple Silicon optimizations applied")
                    elif "cuda" in self.platform:
                        llama_kwargs["n_gpu_layers"] = -1
                        print("🚀 CUDA optimizations applied")
                    else:
                        llama_kwargs["n_gpu_layers"] = 0
                        print("💻 CPU optimizations applied")
            else:
                if self.platform == "macos_apple_silicon":
                    llama_kwargs["n_gpu_layers"] = 1
                    print("🍎 Apple Silicon optimizations applied")
                elif "cuda" in self.platform:
                    llama_kwargs["n_gpu_layers"] = -1
                    print("🚀 CUDA optimizations applied")
                else:
                    llama_kwargs["n_gpu_layers"] = 0
                    print("💻 CPU optimizations applied")
        else:
            llama_kwargs["n_gpu_layers"] = loading_config["n_gpu_layers"]
            print(f"🔧 Using config GPU layers: {llama_kwargs['n_gpu_layers']}")
        
        # Load the model
        try:
            self.model = Llama(**llama_kwargs)
            set_model_interface(self.model)  # Make the model available to other modules
            
            # For GGUF models, we don't need a separate tokenizer
            self.tokenizer = self.model
            
            print(f"✅ GGUF model loaded with {llama_kwargs.get('n_gpu_layers', 0)} GPU layers")
            
            # Store config for later use
            self.model_config = model_config
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            raise
    
    def _load_pytorch_model(self, model_path: Path):
        """Load PyTorch model using transformers (fallback)"""
        if not TORCH_AVAILABLE:
            raise ImportError("PyTorch/transformers not available for PyTorch models")
            
        print(f"🔄 Loading PyTorch model: {model_path}")
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            str(model_path),
            trust_remote_code=True,
            use_fast=True
        )
        
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Load model with optimizations
        model_kwargs = {
            "torch_dtype": torch.float16,
            "low_cpu_mem_usage": True,
            "device_map": "auto",
        }
        
        # Check for environment variable overrides
        env_device = os.environ.get("HUDDLE_DEVICE")
        if env_device:
            if env_device in ["cpu", "cuda", "mps"]:
                model_kwargs["device_map"] = {"": env_device}
                print(f"🔧 Using device from environment: {env_device}")
            else:
                print(f"⚠️ Invalid device: {env_device}. Must be 'cpu', 'cuda', or 'mps'.")
        else:
            # Platform-specific settings
            if self.platform == "macos_apple_silicon":
                model_kwargs["device_map"] = {"": "mps"}
            elif "cuda" in self.platform:
                model_kwargs["device_map"] = "auto"
            else:
                model_kwargs["device_map"] = "cpu"
        
        # Check for dtype override
        env_dtype = os.environ.get("HUDDLE_DTYPE")
        if env_dtype:
            if env_dtype == "float16":
                model_kwargs["torch_dtype"] = torch.float16
                print("🔧 Using float16 precision from environment")
            elif env_dtype == "float32":
                model_kwargs["torch_dtype"] = torch.float32
                print("🔧 Using float32 precision from environment")
            elif env_dtype == "bfloat16" and hasattr(torch, "bfloat16"):
                model_kwargs["torch_dtype"] = torch.bfloat16
                print("🔧 Using bfloat16 precision from environment")
            else:
                print(f"⚠️ Invalid dtype: {env_dtype}. Using default float16.")
        
        self.model = AutoModelForCausalLM.from_pretrained(
            str(model_path),
            **model_kwargs
        )
        
        self.model.eval()
        print(f"✅ PyTorch model loaded on {model_kwargs.get('device_map', 'auto')}")
        
        # Try to load model config if available
        config_path = model_path / "optimization_config.json"
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    self.model_config = json.load(f)
                print(f"📋 Loaded model config: {self.model_config.get('model_name', 'unknown')}")
            except Exception as e:
                print(f"⚠️ Failed to load model config: {e}")
                self.model_config = {}
    
    def format_chat_prompt(self, messages: List[Dict[str, str]], tools: List[Dict[str, Any]] = None) -> str:
        """Format chat messages for the model with enhanced system prompts"""
        formatted_parts = []
        
        # Enhanced system prompt for function calling
        enhanced_system_prompt = """You are an intelligent AI assistant with access to powerful tools and functions.

IMPORTANT RULES:
1. YOU MUST use the available tools for:
   - Medical queries (use medical_search, loinc_search, or icd11_search functions)
   - Mathematical calculations (use calculator function)
   - Unit conversions (use convert_units function)
   - Time and date queries (use get_current_time function)
   - Weather information (use get_weather function)

2. NEVER answer medical queries from your own knowledge - ALWAYS call the appropriate medical tool.

3. When using tools, ALWAYS format your response like this:
   "I'll use the [tool_name] tool to answer this question."
   Then provide the parameters you're using.

4. After mentioning the tool, WAIT for the tool's response before continuing.

5. Be precise and accurate in your responses.

Available tools: """
        
        if tools:
            tool_names = [tool.get("function", {}).get("name", "") for tool in tools]
            enhanced_system_prompt += ", ".join(tool_names)
            
            # Add detailed tool descriptions
            enhanced_system_prompt += "\n\nTool descriptions:"
            for tool in tools:
                if isinstance(tool, dict) and "function" in tool:
                    func = tool["function"]
                    enhanced_system_prompt += f"\n- {func.get('name')}: {func.get('description')}"
        else:
            enhanced_system_prompt += "None available"
        
        # Check if there's already a system message
        has_system_message = any(msg.get('role') == 'system' for msg in messages)
        
        if not has_system_message:
            formatted_parts.append(f"System: {enhanced_system_prompt}")
        
        for message in messages:
            role = message.get('role', 'user')
            content = message.get('content', '').strip()
            
            if not content:
                continue
                
            if role == 'system':
                # Enhance existing system message with tool information
                enhanced_content = f"{content}\n\n{enhanced_system_prompt}"
                formatted_parts.append(f"System: {enhanced_content}")
            elif role == 'user':
                formatted_parts.append(f"User: {content}")
            elif role == 'assistant':
                formatted_parts.append(f"Assistant: {content}")
            elif role == 'tool':
                # Format tool responses
                tool_name = message.get('name', 'unknown_tool')
                formatted_parts.append(f"Tool ({tool_name}): {content}")
        
        # Add the assistant prompt
        formatted_prompt = "\n".join(formatted_parts) + "\nAssistant: "
        return formatted_prompt
    
    def generate_response(self, prompt: str, max_tokens: int = 100, 
                         temperature: float = None, top_p: float = None,
                         frequency_penalty: float = None, presence_penalty: float = None,
                         stop: List[str] = None) -> Dict[str, Any]:
        """Generate response using the appropriate model type with config defaults"""
        if not self.is_loaded:
            self.load_model()
        
        # Get runtime defaults from config
        runtime_defaults = getattr(self, 'model_config', {}).get("runtime_defaults", {})
        if temperature is None:
            temperature = runtime_defaults.get("temperature", 0.7)
        if top_p is None:
            top_p = runtime_defaults.get("top_p", 0.9)
        if frequency_penalty is None:
            frequency_penalty = runtime_defaults.get("frequency_penalty", 0.0)
        if presence_penalty is None:
            presence_penalty = runtime_defaults.get("presence_penalty", 0.0)
        if stop is None:
            stop = runtime_defaults.get("stop_sequences", ["User:", "System:"])
        
        start_time = time.time()
        
        if self.model_type == "gguf":
            response = self._generate_gguf(prompt, max_tokens, temperature, top_p, frequency_penalty, presence_penalty, stop)
        else:
            response = self._generate_pytorch(prompt, max_tokens, temperature, top_p, frequency_penalty, presence_penalty, stop)
        
        generation_time = time.time() - start_time
        
        return {
            "response": response,
            "generation_time": generation_time,
            "model_type": self.model_type,
            "tokens_per_second": len(response.split()) / generation_time if generation_time > 0 else 0,
            "config_used": {
                "temperature": temperature,
                "top_p": top_p,
                "frequency_penalty": frequency_penalty,
                "presence_penalty": presence_penalty,
                "max_tokens": max_tokens,
                "stop_sequences": stop
            }
        }
    
    def _generate_gguf(self, prompt: str, max_tokens: int, temperature: float, top_p: float,
                       frequency_penalty: float = 0.0, presence_penalty: float = 0.0, stop: List[str] = None) -> str:
        """Generate using GGUF model with enhanced parameters"""
        try:
            if stop is None:
                stop = ["User:", "System:"]
            
            output = self.model(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                frequency_penalty=frequency_penalty,
                presence_penalty=presence_penalty,
                echo=False,  # Don't echo the prompt
                stop=stop,
            )
            
            return output['choices'][0]['text'].strip()
            
        except Exception as e:
            print(f"❌ GGUF generation error: {e}")
            return f"I apologize, but I encountered an error while generating a response. Please try again."
    
    def _generate_pytorch(self, prompt: str, max_tokens: int, temperature: float, top_p: float,
                         frequency_penalty: float = 0.0, presence_penalty: float = 0.0, stop: List[str] = None) -> str:
        """Generate using PyTorch model with enhanced parameters"""
        try:
            inputs = self.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=1024)
            
            # Move to appropriate device
            if hasattr(self.model, 'device'):
                inputs = {k: v.to(self.model.device) for k, v in inputs.items()}
            
            # Prepare generation kwargs
            generation_kwargs = {
                "max_new_tokens": max_tokens,
                "temperature": temperature,
                "top_p": top_p,
                "do_sample": True,
                "pad_token_id": self.tokenizer.eos_token_id,
                "eos_token_id": self.tokenizer.eos_token_id,
            }
            
            # Add penalty parameters if supported
            if hasattr(self.model, 'config') and hasattr(self.model.config, 'use_cache'):
                generation_kwargs["use_cache"] = True
            
            # Note: frequency_penalty and presence_penalty are not directly supported in transformers
            # but can be implemented via repetition_penalty or custom logic if needed
            
            with torch.no_grad():
                outputs = self.model.generate(**inputs, **generation_kwargs)
            
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            response = response[len(prompt):].strip()
            
            # Apply stop sequences if provided
            if stop:
                for stop_seq in stop:
                    if stop_seq in response:
                        response = response.split(stop_seq)[0].strip()
            
            return response
            
        except Exception as e:
            print(f"❌ PyTorch generation error: {e}")
            return f"I apologize, but I encountered an error while generating a response. Please try again."
    
    async def generate_stream(self, prompt: str, max_tokens: int = 100, temperature: float = None,
                             top_p: float = None, repetition_penalty: float = None,
                             frequency_penalty: float = None, presence_penalty: float = None,
                             stop: List[str] = None) -> AsyncGenerator[str, None]:
        """Generate text with streaming, supporting both GGUF and PyTorch models with config defaults"""
        if not self.is_loaded:
            self.load_model()
        
        # Get runtime defaults from config
        runtime_defaults = getattr(self, 'model_config', {}).get("runtime_defaults", {})
        if temperature is None:
            temperature = runtime_defaults.get("temperature", 0.7)
        if top_p is None:
            top_p = runtime_defaults.get("top_p", 0.9)
        if repetition_penalty is None:
            repetition_penalty = runtime_defaults.get("repetition_penalty", 1.1)
        if frequency_penalty is None:
            frequency_penalty = runtime_defaults.get("frequency_penalty", 0.0)
        if presence_penalty is None:
            presence_penalty = runtime_defaults.get("presence_penalty", 0.0)
        if stop is None:
            stop = runtime_defaults.get("stop_sequences", ["User:", "System:"])
        
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
                    frequency_penalty=frequency_penalty,
                    presence_penalty=presence_penalty,
                    repeat_penalty=repetition_penalty,
                    stream=True,
                    echo=False,
                    stop=stop
                )
                
                for chunk in response:
                    if 'choices' in chunk and len(chunk['choices']) > 0:
                        choice = chunk['choices'][0]
                        if 'text' in choice and choice['text']:
                            await asyncio.sleep(0)  # Allow other tasks to run
                            yield choice['text']
                            
            else:
                # PyTorch model generation (simplified streaming)
                print(f"🔧 PyTorch streaming generation: max_tokens={max_tokens}")
                
                # For PyTorch, we'll simulate streaming by generating in chunks
                inputs = self.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=1024)
                
                if hasattr(self.model, 'device'):
                    inputs = {k: v.to(self.model.device) for k, v in inputs.items()}
                
                # Generate full response first (PyTorch doesn't have native streaming)
                with torch.no_grad():
                    outputs = self.model.generate(
                        **inputs,
                        max_new_tokens=max_tokens,
                        temperature=temperature,
                        top_p=top_p,
                        do_sample=True,
                        pad_token_id=self.tokenizer.eos_token_id,
                        eos_token_id=self.tokenizer.eos_token_id,
                    )
                
                response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
                response = response[len(prompt):].strip()
                
                # Stream the response word by word
                words = response.split()
                for i, word in enumerate(words):
                    if i == 0:
                        yield word
                    else:
                        yield f" {word}"
                    await asyncio.sleep(0.05)  # Small delay for streaming effect
                            
        except Exception as e:
            print(f"❌ Streaming generation error: {e}")
            yield f"Error during streaming generation: {str(e)}"
    
    # Note: Function detection is now handled by the enhanced function_detector
    # from function_validation module for better security and validation
    
    def execute_function_calls(self, tool_calls: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Execute function calls with enhanced error handling and validation"""
        results = []
        
        # Check if function tools are available
        if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
            return [{
                "tool_call_id": "error",
                "role": "tool",
                "name": "error",
                "content": json.dumps({
                    "error": "Function tools not available",
                    "success": False
                })
            }]
        
        for tool_call in tool_calls:
            if tool_call.get("type") == "function":
                function_name = tool_call["function"]["name"]
                tool_call_id = tool_call.get("id", f"call_{int(time.time())}")
                
                try:
                    # Parse arguments
                    arguments = json.loads(tool_call["function"]["arguments"])
                    
                    # Additional validation before execution (if available)
                    if FUNCTION_VALIDATION_AVAILABLE and function_validator:
                        validation = function_validator.validate_function_arguments(function_name, arguments)
                        
                        if not validation.is_valid:
                            results.append({
                                "tool_call_id": tool_call_id,
                                "role": "tool",
                                "name": function_name,
                                "content": json.dumps({
                                    "error": f"Validation failed: {validation.error_message}",
                                    "success": False
                                })
                            })
                            continue
                        
                        # Execute function with validated arguments
                        result = function_tools.execute_function(function_name, validation.sanitized_args)
                    else:
                        # Execute function without validation
                        result = function_tools.execute_function(function_name, arguments)
                    
                    results.append({
                        "tool_call_id": tool_call_id,
                        "role": "tool",
                        "name": function_name,
                        "content": json.dumps(result)
                    })
                    
                except json.JSONDecodeError as e:
                    results.append({
                        "tool_call_id": tool_call_id,
                        "role": "tool",
                        "name": function_name,
                        "content": json.dumps({
                            "error": f"Invalid JSON arguments: {str(e)}",
                            "success": False
                        })
                    })
                except Exception as e:
                    results.append({
                        "tool_call_id": tool_call_id,
                        "role": "tool",
                        "name": function_name,
                        "content": json.dumps({
                            "error": f"Execution error: {str(e)}",
                            "success": False
                        })
                    })
        
        return results
    
    def get_memory_info(self) -> Dict[str, Any]:
        """Get current memory usage"""
        memory = psutil.virtual_memory()
        
        # Get model file size
        model_size = "Unknown"
        if self.model_path and self.model_path.exists():
            if self.model_path.is_file():
                model_size = f"{self.model_path.stat().st_size / (1024**3):.1f}GB"
            else:
                total_size = sum(f.stat().st_size for f in self.model_path.rglob('*') if f.is_file())
                model_size = f"{total_size / (1024**3):.1f}GB"
        
        return {
            "total_gb": memory.total / (1024**3),
            "available_gb": memory.available / (1024**3),
            "used_gb": memory.used / (1024**3),
            "percent_used": memory.percent,
            "model_type": self.model_type,
            "model_size": model_size,
            "model_path": str(self.model_path) if self.model_path else None
        }

# Global model instance
model_manager = None
start_time = time.time()

def init_model():
    global model_manager
    model_manager = OptimizedModelManager()
    model_manager.load_model()

# FastAPI app with lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting Optimized GGUF FastAPI server...")
    init_model()
    yield
    print("🛑 Shutting down server...")

app = FastAPI(
    title="Optimized GGUF Llama Server",
    description="High-performance server supporting both GGUF and PyTorch models",
    version="3.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return HTMLResponse(content=open("static/index.html", "r").read())

@app.get("/health", response_model=HealthResponse)
async def health():
    memory_info = model_manager.get_memory_info() if model_manager else {}
    uptime = time.time() - start_time
    
    return HealthResponse(
        status="healthy" if model_manager and model_manager.is_loaded else "loading",
        model_loaded=model_manager.is_loaded if model_manager else False,
        model_type=model_manager.model_type if model_manager else "unknown",
        device=model_manager.platform if model_manager else "unknown",
        model_size=memory_info.get("model_size", "unknown"),
        uptime=uptime,
        memory_usage=memory_info
    )

@app.post("/api/location/update")
async def update_location(request: Request):
    """Update location from browser geolocation"""
    if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
        return {"success": False, "error": "Function tools not available"}
    
    try:
        data = await request.json()
        lat = data.get("lat")
        lon = data.get("lon")
        accuracy = data.get("accuracy")
        
        if lat and lon:
            # Update the function tools location cache
            updated_location = function_tools.update_location_from_browser(lat, lon, accuracy)
            return {"success": True, "location": updated_location}
        else:
            return {"success": False, "error": "Missing coordinates"}
            
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.get("/api/location/request")
async def request_location():
    """Request location permission from user"""
    if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
        return {"success": False, "error": "Function tools not available"}
    return function_tools.request_precise_location()

@app.get("/api/location/script")
async def get_location_script():
    """Get JavaScript for browser location detection"""
    return {"script": function_tools.get_browser_location_script()}

@app.post("/v1/chat/completions")
async def create_chat_completion_endpoint(request: ChatCompletionRequest):
    """OpenAI-compatible chat completion endpoint"""
    try:
        # Get the model
        model = get_model_interface()
        
        # Check if tools are provided and handle tool calling
        if request.tools and request.tool_choice != "none":
            # Format prompt for tool usage
            prompt = model_manager.format_chat_prompt(
                [msg.dict() for msg in request.messages], 
                request.tools
            )
            
            # Generate response with tools context
            response_data = model_manager.generate_response(
                prompt,
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                frequency_penalty=request.frequency_penalty,
                presence_penalty=request.presence_penalty,
                stop=request.stop
            )
            
            response_text = response_data["response"]
            
            # Check if the response contains tool calls
            tool_calls = []
            
            # Look for tool call patterns in the response
            import re
            
            # Match function call patterns like "Using the calculator tool" or "I'll use the medical_search tool"
            tool_patterns = [
                r"(?:using|use|with|through|via|call|calling|execute|executing|running|apply|applying)\s+(?:the\s+)?([a-zA-Z_]+)\s+(?:tool|function)",
                r"I(?:'ll|\s+will)\s+(?:use|call|execute|run|apply)\s+(?:the\s+)?([a-zA-Z_]+)",
                r"([a-zA-Z_]+)\s+(?:tool|function)\s+(?:returns|returned|gives|gave|shows|showed|provides|provided)",
                r"I'll use the ([a-zA-Z_]+) tool",
                r"Let me use the ([a-zA-Z_]+) tool",
                r"I need to use the ([a-zA-Z_]+)",
                r"I should use the ([a-zA-Z_]+)",
                r"Using ([a-zA-Z_]+) to",
                r"Based on (?:your|these) symptoms, I'll use the ([a-zA-Z_]+)",
                r"To provide a diagnosis, I'll use the ([a-zA-Z_]+)",
                r"For medical diagnosis, I'll use the ([a-zA-Z_]+)",
                r"Let me diagnose this using the ([a-zA-Z_]+)"
            ]
            
            detected_tools = []
            for pattern in tool_patterns:
                matches = re.findall(pattern, response_text, re.IGNORECASE)
                detected_tools.extend(matches)
            
            # Filter to only include defined tools
            available_tool_names = [tool["function"]["name"] for tool in request.tools if isinstance(tool, dict) and "function" in tool]
            detected_tools = [tool for tool in detected_tools if tool.lower() in [t.lower() for t in available_tool_names]]
            
            # If tools were detected, execute them
            if detected_tools:
                print(f"🔧 Detected tool usage: {detected_tools}")
                
                # Find the first detected tool that matches an available tool
                tool_name = None
                for detected in detected_tools:
                    for available in available_tool_names:
                        if detected.lower() == available.lower():
                            tool_name = available
                            break
                    if tool_name:
                        break
                
                if tool_name:
                    # Extract parameters from the response
                    # This is a simplified extraction - in production, you'd want more robust parameter extraction
                    param_pattern = r"(?:parameters|arguments|inputs|with)(?:\s+are|\s+is|\s*:\s*|\s+being|\s+as)?\s+(?:\{(.*?)\}|\"(.*?)\")"
                    param_match = re.search(param_pattern, response_text, re.IGNORECASE | re.DOTALL)
                    
                    parameters = {}
                    if param_match:
                        param_text = param_match.group(1) or param_match.group(2)
                        
                        # Try to parse as JSON
                        try:
                            parameters = json.loads("{" + param_text + "}")
                        except:
                            # If JSON parsing fails, try to extract key-value pairs
                            kv_pattern = r"(?:\"|\')?([\w_]+)(?:\"|\')?(?:\s*:\s*|\s*=\s*)(?:\"|\')?([\w\s\._-]+)(?:\"|\')?(?:,|$)"
                            kv_matches = re.findall(kv_pattern, param_text)
                            parameters = {k: v for k, v in kv_matches}
                    
                    # Extract query from user message if parameters are empty
                    if not parameters and tool_name in ["medical_search", "icd11_search", "loinc_search", "umls_search", "pubmed_search", "medical_diagnosis"]:
                        user_messages = [msg for msg in request.messages if msg.role == "user"]
                        assistant_messages = [msg for msg in request.messages if msg.role == "assistant"]
                        
                        if user_messages:
                            last_user_message = user_messages[-1].content
                            
                            # Check if this is a formatting request rather than a medical query
                            formatting_patterns = [
                                r"(?:please|can you|could you)?\s*(?:clean|fix|improve|change|update|format|reformat|restructure|organize|present|display|show)\s+(?:the|this|that|your)?\s*(?:format|formatting|response|answer|result|output|text|content|information|presentation)",
                                r"(?:make|render|display)\s+(?:this|that|it|the response|the answer|the result|the output)\s+(?:more|better|clearer|cleaner|nicer|prettier|easier to read|more readable|more presentable)",
                                r"(?:no|without)\s+(?:queries|query)",
                                r"(?:better|cleaner|nicer|prettier|more readable|more presentable)\s+(?:format|formatting|presentation|display|layout)"
                            ]
                            
                            # Add patterns for other general (non-medical) requests
                            general_request_patterns = [
                                r"(?:thank|thanks|thank you)",
                                r"(?:good|great|excellent|amazing|wonderful|fantastic)",
                                r"(?:hi|hello|hey)",
                                r"(?:bye|goodbye|see you)",
                                r"(?:who are you|what can you do|what are your capabilities|tell me about yourself)",
                                r"(?:help|assist|support)",
                                r"(?:stop|quit|exit|cancel)",
                                r"(?:repeat|say again|tell me again)",
                                r"(?:summarize|summary|summarization)",
                                r"(?:explain|explanation|clarify|clarification)",
                                r"(?:continue|go on|proceed|next)",
                                r"(?:previous|back|before)",
                                r"(?:correct|right|incorrect|wrong)",
                                r"(?:yes|no|maybe)",
                                r"(?:understood|got it|i see|i understand)",
                            ]
                            
                            is_formatting_request = any(re.search(pattern, last_user_message, re.IGNORECASE) for pattern in formatting_patterns)
                            is_general_request = any(re.search(pattern, last_user_message, re.IGNORECASE) for pattern in general_request_patterns)
                            
                            # Check for specific non-medical keywords
                            non_medical_keywords = ["format", "formatting", "present", "presentation", "display", "layout", 
                                                  "structure", "organize", "clean", "clear", "readable", "thank", "thanks",
                                                  "hello", "hi", "hey", "goodbye", "bye", "help", "assist"]
                            
                            contains_non_medical_keywords = any(keyword in last_user_message.lower() for keyword in non_medical_keywords)
                            
                            # Check if this is a short message (likely a general request)
                            is_short_message = len(last_user_message.split()) < 5
                            
                            if is_formatting_request or (is_general_request and is_short_message) or (contains_non_medical_keywords and is_short_message):
                                # This is a general request, not a medical query
                                # Get previous messages for context
                                previous_messages = []
                                for i, msg in enumerate(request.messages):
                                    if i < len(request.messages) - 1:  # Skip the last user message which we already have
                                        role = "You" if msg.role == "assistant" else "User"
                                        previous_messages.append(f"{role}: {msg.content}")
                                
                                previous_context = "\n".join(previous_messages) if previous_messages else "No previous messages"
                                
                                # Create a prompt for the model to handle the general request
                                general_prompt = f"""The user has made a general request: "{last_user_message}"

Previous conversation:
{previous_context}

This appears to be a non-medical request. If it's about formatting or presentation, please format the previous medical information in a clear, organized way with proper headings and bullet points.

If it's a general question, greeting, or other non-medical request, respond appropriately without using medical tools.

Response:"""
                                
                                # Generate response
                                response_data = model_manager.generate_response(
                                    general_prompt,
                                    max_tokens=500,
                                    temperature=0.3
                                )
                                
                                return {
                                    "id": f"chatcmpl-{int(time.time())}",
                                    "object": "chat.completion",
                                    "created": int(time.time()),
                                    "model": request.model,
                                    "choices": [{
                                        "index": 0,
                                        "message": {
                                            "role": "assistant",
                                            "content": response_data["response"]
                                        }
                                    }],
                                    "usage": {
                                        "prompt_tokens": len(general_prompt.split()),
                                        "completion_tokens": len(response_data["response"].split()),
                                        "total_tokens": len(general_prompt.split()) + len(response_data["response"].split())
                                    }
                                }
                    
                    # Get context from previous messages
                    context = ""
                    if len(user_messages) > 1 and len(assistant_messages) > 0:
                        # Get the previous user query and assistant response for context
                        prev_user_message = user_messages[-2].content if len(user_messages) > 1 else ""
                        prev_assistant_message = assistant_messages[-1].content if assistant_messages else ""
                        
                        # Extract medical conditions or topics from previous messages
                        medical_conditions = re.findall(r'(?:about|regarding|concerning|on|for)\s+([a-zA-Z0-9\s\-]+(?:disease|syndrome|condition|disorder|infection|virus|bacteria|symptoms|diagnosis|treatment|diabetes|cancer|heart|asthma))', 
                                                      prev_user_message + " " + prev_assistant_message, 
                                                      re.IGNORECASE)
                        
                        if medical_conditions:
                            context = f"In the context of {medical_conditions[0].strip()}, "
                    
                    # Try to extract specific medical terms or conditions
                    medical_terms = re.findall(r'(?:about|regarding|concerning|on|for)\s+([a-zA-Z0-9\s\-]+(?:disease|syndrome|condition|disorder|infection|virus|bacteria|symptoms|diagnosis|treatment))', last_user_message, re.IGNORECASE)
                    
                    if medical_terms:
                        parameters = {"query": medical_terms[0].strip()}
                    else:
                        # If no specific terms found, use the whole message with context
                        parameters = {"query": context + last_user_message}
                        
                    # Add user type if available
                    if "doctor" in last_user_message.lower() or "physician" in last_user_message.lower():
                        parameters["user_type"] = "doctor"
                    elif "nurse" in last_user_message.lower():
                        parameters["user_type"] = "nurse"
                    elif "researcher" in last_user_message.lower() or "study" in last_user_message.lower():
                        parameters["user_type"] = "researcher"
                    else:
                        parameters["user_type"] = "patient"
                
                # Extract symptoms for medical diagnosis
                if not parameters and tool_name == "medical_diagnosis":
                    user_messages = [msg for msg in request.messages if msg.role == "user"]
                    if user_messages:
                        last_user_message = user_messages[-1].content
                        
                        # Try to extract symptoms
                        symptoms_patterns = [
                            r"(?:I have|I've been having|I've got|I am having|I'm having|experiencing|suffering from)\s+([^\.]+)",
                            r"(?:symptoms|problems|issues)(?:\s+are|\s+include|\s*:\s*)?\s+([^\.]+)",
                            r"(?:complaining of|troubled by)\s+([^\.]+)"
                        ]
                        
                        for pattern in symptoms_patterns:
                            symptoms_match = re.search(pattern, last_user_message, re.IGNORECASE)
                            if symptoms_match:
                                parameters["symptoms"] = symptoms_match.group(1).strip()
                                break
                        
                        # If no specific symptoms found, use the whole message
                        if "symptoms" not in parameters:
                            parameters["symptoms"] = last_user_message
                        
                        # Try to extract age
                        age_match = re.search(r"(?:I am|I'm|patient is)\s+(\d+)(?:\s+years?\s+old)?", last_user_message, re.IGNORECASE)
                        if age_match:
                            try:
                                parameters["patient_age"] = int(age_match.group(1))
                            except:
                                pass
                        
                        # Try to extract gender
                        if re.search(r"\b(?:I am|I'm|patient is)\s+(?:a\s+)?(?:male|man|boy)\b", last_user_message, re.IGNORECASE):
                            parameters["patient_gender"] = "male"
                        elif re.search(r"\b(?:I am|I'm|patient is)\s+(?:a\s+)?(?:female|woman|girl)\b", last_user_message, re.IGNORECASE):
                            parameters["patient_gender"] = "female"
                        
                        # Try to extract medical history
                        history_match = re.search(r"(?:medical history|history of|previously diagnosed with|past conditions?)\s+(?:includes?|is|of)?\s+([^\.]+)", last_user_message, re.IGNORECASE)
                        if history_match:
                            parameters["medical_history"] = history_match.group(1).strip()
                
                # For calculator, try to extract the expression
                if not parameters and tool_name == "calculator":
                    calc_pattern = r"calculate\s+([\d\s\+\-\*\/\(\)\^\.\%]+)"
                    calc_match = re.search(calc_pattern, response_text, re.IGNORECASE)
                    if calc_match:
                        parameters = {"expression": calc_match.group(1).strip()}
                
                # Import function tools manager
                from function_tools import function_tools
                
                # Execute the function
                print(f"🔧 Executing {tool_name} with parameters: {parameters}")
                result = function_tools.execute_function(tool_name, parameters)
                
                # Extract databases used if present in the result
                databases_used = []
                if isinstance(result, dict) and isinstance(result.get("result"), str):
                    # Look for the databases used information in the result
                    db_match = re.search(r"Databases used in this search: ([\w\-,\s]+)", result["result"])
                    if db_match:
                        databases_string = db_match.group(1)
                        databases_used = [db.strip() for db in databases_string.split(',')]
                        
                        # Remove the databases used line from the result
                        result["result"] = re.sub(r"\n\nDatabases used in this search: [\w\-,\s]+", "", result["result"])
                
                # If AI generation is requested and the result is text, enhance it with the AI model
                # Always use AI enhancement for chat completions
                if isinstance(result.get("result"), str) and model_manager:
                    try:
                        # Create a prompt for the model to enhance the result
                        prompt = f"""The following is a result from a tool called {tool_name}:

{result.get("result")}

Please enhance this information to make it more comprehensive, well-structured, and user-friendly.
Add any relevant medical context, explanations, or additional information that would be helpful.
Format your response with clear headings, bullet points where appropriate, and a logical flow.
DO NOT include disclaimers or warnings about consulting healthcare professionals.
IMPORTANT: Respond as if you are directly answering the user's question. Do not mention that you are enhancing a tool result.

Enhanced response:"""

                        # Generate enhanced response
                        response_data = model_manager.generate_response(
                            prompt,
                            max_tokens=500,
                            temperature=0.3
                        )
                        
                        enhanced_result = response_data["response"].strip()
                        
                        # Add the enhanced result to the response
                        result["enhanced_result"] = enhanced_result
                        result["ai_enhanced"] = True
                        
                        # Replace the original result with the enhanced one for better integration
                        if "result" in result and isinstance(result["result"], str):
                            result["original_result"] = result["result"]
                            result["result"] = enhanced_result
                    except Exception as e:
                        print(f"❌ Error enhancing result with AI: {str(e)}")
                        result["ai_enhanced"] = False
                
                if result:
                    # Create a new system message with the tool result
                    tool_result_message = f"Tool '{tool_name}' returned: {json.dumps(result)}"
                    print(f"🔧 Tool result: {tool_result_message}")
                    
                    # Add the tool result to the messages
                    new_messages = request.messages + [
                        ChatMessage(role="system", content=tool_result_message)
                    ]
                    
                    # Generate final response with tool results
                    final_prompt = model_manager.format_chat_prompt(
                        [msg.dict() for msg in new_messages], 
                        request.tools
                    )
                    
                    final_response_data = model_manager.generate_response(
                        final_prompt,
                        max_tokens=request.max_tokens,
                        temperature=request.temperature,
                        top_p=request.top_p,
                        frequency_penalty=request.frequency_penalty,
                        presence_penalty=request.presence_penalty,
                        stop=request.stop
                    )
                    
                    # Extract the tool result content
                    tool_result = None
                    if isinstance(result, dict) and "result" in result:
                        tool_result = result["result"]
                    
                    # Create a more integrated response
                    integrated_response = final_response_data["response"]
                    
                    # If the response doesn't seem to incorporate the tool result well,
                    # create a better integrated response
                    if tool_result and isinstance(tool_result, str) and tool_result not in integrated_response:
                        # Extract previous messages for context
                        previous_messages = []
                        for i, msg in enumerate(request.messages):
                            if i < len(request.messages) - 1:  # Skip the last user message which we already have
                                role = "You" if msg.role == "assistant" else "User"
                                previous_messages.append(f"{role}: {msg.content}")
                        
                        previous_context = "\n".join(previous_messages) if previous_messages else "No previous messages"
                        
                        # Check if this is a follow-up question
                        is_followup = any(term in user_messages[-1].content.lower() for term in 
                                         ["what about", "how about", "what if", "verses", "versus", "compared to", 
                                          "difference between", "in contrast", "this", "that", "also", "and", "but", 
                                          "what does", "how does", "why does"])
                        
                        # Create a prompt specifically for integrating the tool result
                        integration_prompt = f"""You are answering the user's question: "{user_messages[-1].content}"

Previous conversation:
{previous_context}

The tool {tool_name} returned this information: 
{tool_result}

{"This appears to be a follow-up question to the previous conversation. Make sure to connect your answer to the previous context." if is_followup else ""}

Based on this information and the conversation history, provide a direct, comprehensive answer to the user's question.
DO NOT include disclaimers or warnings about consulting healthcare professionals.
DO NOT mention that you used a tool or reference the tool result. Simply provide the answer as if you knew it directly.
Be concise, clear, and helpful.

Answer:"""
                        
                        integration_response = model_manager.generate_response(
                            integration_prompt,
                            max_tokens=request.max_tokens,
                            temperature=0.3,
                            top_p=0.9
                        )
                        
                        integrated_response = integration_response["response"]
                    
                    # Create response with tool usage
                    return {
                        "id": f"chatcmpl-{int(time.time())}",
                        "object": "chat.completion",
                        "created": int(time.time()),
                        "model": request.model,
                        "choices": [{
                            "index": 0,
                            "message": {
                                "role": "assistant",
                                "content": integrated_response,
                                "tool_calls": [{
                                    "id": f"call_{int(time.time())}",
                                    "type": "function",
                                    "function": {
                                        "name": tool_name,
                                        "arguments": json.dumps(parameters)
                                    }
                                }]
                            },
                            "finish_reason": "tool_calls"
                        }],
                        "usage": {
                            "prompt_tokens": len(prompt.split()),
                            "completion_tokens": len(integrated_response.split()),
                            "total_tokens": len(prompt.split()) + len(integrated_response.split())
                        }
                    }
        
        # Use the enhanced chat completion function with system prompt
        response = create_chat_completion(
            request.messages,
            model,
            temperature=request.temperature,
            top_p=request.top_p,
            max_tokens=request.max_tokens,
            stream=request.stream,
            stop=request.stop
        )
        
        # Return the response
        return response
    except Exception as e:
        print(f"❌ Chat completion error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Chat completion failed: {str(e)}")

@app.get("/model/info")
async def model_info():
    """Get detailed model information"""
    if not model_manager:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    memory_info = model_manager.get_memory_info()
    
    # Get model config if available
    model_config = getattr(model_manager, 'model_config', {})
    
    return {
        "model_name": "HuddleAI",
        "model_type": model_manager.model_type,
        "model_path": str(model_manager.model_path) if model_manager.model_path else None,
        "platform": model_manager.platform,
        "configuration": model_manager.config,
        "model_config": model_config,
        "model_loaded": model_manager.is_loaded,
        "memory_usage": memory_info,
        "capabilities": {
            "gguf_support": LLAMA_CPP_AVAILABLE,
            "pytorch_support": TORCH_AVAILABLE,
            "current_backend": model_manager.model_type,
            "function_calling": True,
            "streaming": True
        }
    }

@app.get("/functions")
async def list_functions():
    """Get available function definitions with validation info"""
    validation_info = {}
    
    if function_validator:
        validation_info = {
            "rate_limits": getattr(function_validator, 'rate_limits', {}),
            "security_features": [
                "Input sanitization",
                "Rate limiting",
                "Expression safety checking",
                "Parameter validation",
                "Negation detection"
            ],
            "negation_patterns_supported": len(getattr(function_validator, 'negation_patterns', []))
        }
    else:
        validation_info = {
            "rate_limits": {},
            "security_features": ["Basic function calling"],
            "negation_patterns_supported": 0
        }
    
    return {
        "functions": function_tools.get_function_definitions(),
        "count": len(function_tools.functions),
        "available_tools": list(function_tools.functions.keys()),
        "validation": validation_info
    }

@app.get("/validation/stats")
async def validation_stats():
    """Get function calling validation statistics"""
    stats = {
        "rate_limits": {},
        "current_call_counts": {},
        "security_patterns": {
            "unsafe_calculator_patterns": 0,
            "negation_patterns": 0
        },
        "supported_patterns": {},
        "confirmation_stats": {}
    }
    
    if function_validator:
        stats["rate_limits"] = getattr(function_validator, 'rate_limits', {})
        stats["current_call_counts"] = {
            func_name: len(calls) 
            for func_name, calls in getattr(function_validator, 'call_history', {}).items()
        }
        stats["security_patterns"] = {
            "unsafe_calculator_patterns": len(getattr(function_validator, 'unsafe_calculator_patterns', [])),
            "negation_patterns": len(getattr(function_validator, 'negation_patterns', []))
        }
    
    if function_detector:
        stats["supported_patterns"] = {
            func_name: len(patterns) 
            for func_name, patterns in getattr(function_detector, 'function_patterns', {}).items()
        }
    
    if model_manager and model_manager.confirmation_system:
        stats["confirmation_stats"] = model_manager.confirmation_system.get_confirmation_stats()
    
    return stats

@app.post("/v1/chat/completions/confirm")
async def confirm_web_search(request: Dict[str, Any]):
    """Handle web search confirmation responses"""
    try:
        if not model_manager:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        session_id = request.get("session_id")
        user_response = request.get("user_response", "")
        
        if not session_id:
            raise HTTPException(status_code=400, detail="Session ID required")
        
        # Process confirmation response
        should_search, response_message, fallback_knowledge = model_manager.confirmation_system.process_confirmation_response(
            user_response, session_id
        )
        
        if should_search:
            # Get the confirmation details
            confirmation = model_manager.confirmation_system.get_confirmation_by_id(session_id)
            if confirmation:
                # Execute the web search
                search_result = function_tools._web_search(confirmation.extracted_search_term, 5)
                
                # Clean up the confirmation session
                model_manager.confirmation_system.cleanup_confirmation(session_id)
                
                return {
                    "id": f"chatcmpl-{int(time.time())}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": "HuddleAI",
                    "choices": [{
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": f"{response_message}\n\n{search_result}"
                        },
                        "finish_reason": "stop"
                    }],
                    "usage": {
                        "prompt_tokens": len(user_response.split()),
                        "completion_tokens": len(response_message.split()) + len(search_result.split()),
                        "total_tokens": len(user_response.split()) + len(response_message.split()) + len(search_result.split())
                    }
                }
        else:
            # Clean up the confirmation session
            model_manager.confirmation_system.cleanup_confirmation(session_id)
            
            # Include fallback knowledge if available
            final_content = response_message
            if fallback_knowledge:
                final_content += f"\n\n{fallback_knowledge}"
            
            return {
                "id": f"chatcmpl-{int(time.time())}",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": "HuddleAI",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": final_content
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": len(user_response.split()),
                    "completion_tokens": len(final_content.split()),
                    "total_tokens": len(user_response.split()) + len(final_content.split())
                }
            }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Confirmation failed: {str(e)}")

@app.post("/api/execute_tool")
async def execute_tool_endpoint(request: Request):
    """Execute a tool directly with user permission"""
    try:
        data = await request.json()
        
        tool_name = data.get("tool_name")
        parameters = data.get("parameters", {})
        use_ai_generation = data.get("use_ai_generation", True)
        
        if not tool_name:
            raise HTTPException(status_code=400, detail="Tool name is required")
        
        # Check if this is a general request rather than a medical query
        if tool_name in ["medical_search", "medical_diagnosis", "icd11_search", "loinc_search", "umls_search", "pubmed_search"]:
            query = parameters.get("query", "") if parameters else ""
            symptoms = parameters.get("symptoms", "") if parameters else ""
            
            # Combine query and symptoms for checking
            text_to_check = (query + " " + symptoms).lower()
            
            # Define patterns for general requests
            formatting_patterns = [
                r"(?:please|can you|could you)?\s*(?:clean|fix|improve|change|update|format|reformat|restructure|organize|present|display|show)\s+(?:the|this|that|your)?\s*(?:format|formatting|response|answer|result|output|text|content|information|presentation)",
                r"(?:make|render|display)\s+(?:this|that|it|the response|the answer|the result|the output)\s+(?:more|better|clearer|cleaner|nicer|prettier|easier to read|more readable|more presentable)",
                r"(?:no|without)\s+(?:queries|query)",
                r"(?:better|cleaner|nicer|prettier|more readable|more presentable)\s+(?:format|formatting|presentation|display|layout)"
            ]
            
            # Add patterns for other general (non-medical) requests
            general_request_patterns = [
                r"(?:thank|thanks|thank you)",
                r"(?:good|great|excellent|amazing|wonderful|fantastic)",
                r"(?:hi|hello|hey)",
                r"(?:bye|goodbye|see you)",
                r"(?:who are you|what can you do|what are your capabilities|tell me about yourself)",
                r"(?:help|assist|support)",
                r"(?:stop|quit|exit|cancel)",
                r"(?:repeat|say again|tell me again)",
                r"(?:summarize|summary|summarization)",
                r"(?:explain|explanation|clarify|clarification)",
                r"(?:continue|go on|proceed|next)",
                r"(?:previous|back|before)",
                r"(?:correct|right|incorrect|wrong)",
                r"(?:yes|no|maybe)",
                r"(?:understood|got it|i see|i understand)",
            ]
            
            is_formatting_request = any(re.search(pattern, text_to_check) for pattern in formatting_patterns)
            is_general_request = any(re.search(pattern, text_to_check) for pattern in general_request_patterns)
            
            # Check for specific non-medical keywords
            non_medical_keywords = ["format", "formatting", "present", "presentation", "display", "layout", 
                                  "structure", "organize", "clean", "clear", "readable", "thank", "thanks",
                                  "hello", "hi", "hey", "goodbye", "bye", "help", "assist"]
            
            contains_non_medical_keywords = any(keyword in text_to_check for keyword in non_medical_keywords)
            
            # Check if this is a short message (likely a general request)
            is_short_message = len(text_to_check.split()) < 5
            
            if is_formatting_request or (is_general_request and is_short_message) or (contains_non_medical_keywords and is_short_message):
                # This is a general request, not a medical query
                # Generate a response using the model directly
                general_prompt = f"""The user has made a general request: "{text_to_check}"

This appears to be a non-medical request. If it's about formatting or presentation, please format medical information in a clear, organized way with proper headings and bullet points.

If it's a general question, greeting, or other non-medical request, respond appropriately without using medical tools.

Response:"""
                
                # Generate response
                response_data = model_manager.generate_response(
                    general_prompt,
                    max_tokens=500,
                    temperature=0.3
                )
                
                return {
                    "tool": "general_response",
                    "parameters": parameters,
                    "result": {
                        "result": response_data["response"],
                        "success": True,
                        "ai_enhanced": True,
                        "enhanced_result": response_data["response"]
                    },
                    "databases_used": [],
                    "timestamp": int(time.time())
                }
        
        # Import function tools
        from function_tools import function_tools
        
        # Check if tool exists
        if tool_name not in function_tools.functions:
            raise HTTPException(status_code=404, detail=f"Tool '{tool_name}' not found")
        
        # Execute the function
        print(f"🔧 Directly executing {tool_name} with parameters: {parameters}")
        result = function_tools.execute_function(tool_name, parameters)
        
        # Extract databases used if present in the result
        databases_used = []
        if isinstance(result, dict) and isinstance(result.get("result"), str):
            # Look for the databases used information in the result
            db_match = re.search(r"Databases used in this search: ([\w\-,\s]+)", result["result"])
            if db_match:
                databases_string = db_match.group(1)
                databases_used = [db.strip() for db in databases_string.split(',')]
                
                # Remove the databases used line from the result
                result["result"] = re.sub(r"\n\nDatabases used in this search: [\w\-,\s]+", "", result["result"])
        
        # If AI generation is requested and the result is text, enhance it with the AI model
        if use_ai_generation and isinstance(result.get("result"), str) and model_manager:
            try:
                # Create a prompt for the model to enhance the result
                prompt = f"""The following is a result from a tool called {tool_name}:

{result.get("result")}

Please enhance this information to make it more comprehensive, well-structured, and user-friendly.
Add any relevant medical context, explanations, or additional information that would be helpful.
Format your response with clear headings, bullet points where appropriate, and a logical flow.
DO NOT include disclaimers or warnings about consulting healthcare professionals.
IMPORTANT: Respond as if you are directly answering the user's question. Do not mention that you are enhancing a tool result.

Enhanced response:"""

                # Generate enhanced response
                response_data = model_manager.generate_response(
                    prompt,
                    max_tokens=500,
                    temperature=0.3
                )
                
                enhanced_result = response_data["response"].strip()
                
                # Add the enhanced result to the response
                result["enhanced_result"] = enhanced_result
                result["ai_enhanced"] = True
                
                # Replace the original result with the enhanced one for better integration
                if "result" in result and isinstance(result["result"], str):
                    result["original_result"] = result["result"]
                    result["result"] = enhanced_result
            except Exception as e:
                print(f"❌ Error enhancing result with AI: {str(e)}")
                result["ai_enhanced"] = False
        
        return {
            "tool": tool_name,
            "parameters": parameters,
            "result": result,
            "databases_used": databases_used if databases_used else [],
            "timestamp": int(time.time())
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Tool execution error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Tool execution failed: {str(e)}")

SYSTEM_PROMPT = """You are HuddleAI, a helpful medical assistant with access to specialized tools.

When a user asks a question that requires specialized knowledge or calculations:
1. Identify which tool would be most appropriate
2. Use the tool to get accurate information
3. Present the results in a clear, professional manner
4. Maintain conversation context and build upon previous exchanges
5. DO NOT include disclaimers or warnings about consulting healthcare professionals

Available tools include:
- calculator: For mathematical calculations and medical formulas
- medical_search: For general medical information
- medical_diagnosis: For comprehensive diagnostic information
- loinc_search: For lab test information and normal ranges
- icd11_search: For disease classification and diagnostic information
- pubmed_search: For medical research information
- umls_search: For medical terminology and concepts

When using medical formulas, be precise and include units. For example:
- BMI = weight(kg) / height(m)²
- Creatinine Clearance = (140-age) × weight(kg) / (72 × serum creatinine)
- Lung Compliance = tidal volume / (plateau pressure - PEEP)

Always prioritize accuracy and clarity in your responses."""

def create_chat_completion(messages, model, **kwargs):
    """Create a chat completion with the system prompt prepended"""
    # Add system prompt if not already present
    if not any(msg.get("role") == "system" for msg in messages):
        messages = [{"role": "system", "content": SYSTEM_PROMPT}] + messages
    
    # Call the model
    return model.create_chat_completion(messages, **kwargs)

_MODEL_INTERFACE = None

def get_model_interface():
    """Get the loaded model interface for use by other modules"""
    return _MODEL_INTERFACE

def set_model_interface(model):
    """Set the model interface for use by other modules"""
    global _MODEL_INTERFACE
    _MODEL_INTERFACE = model

if __name__ == "__main__":
    import argparse
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="HuddleAI GGUF Server")
    parser.add_argument("--model", type=str, help="Path to model directory or file")
    parser.add_argument("--device", type=str, choices=["cpu", "cuda", "mps"], help="Device to use")
    parser.add_argument("--n-gpu-layers", type=int, help="Number of layers to offload to GPU")
    parser.add_argument("--n-ctx", type=int, help="Context size")
    parser.add_argument("--n-batch", type=int, help="Batch size for processing")
    parser.add_argument("--n-threads", type=int, help="Number of threads")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8002, help="Port to bind to")
    
    args = parser.parse_args()
    
    # Set environment variables from command line arguments
    if args.model:
        os.environ["HUDDLE_MODEL_PATH"] = args.model
    if args.device:
        os.environ["HUDDLE_DEVICE"] = args.device
    if args.n_gpu_layers is not None:
        os.environ["HUDDLE_N_GPU_LAYERS"] = str(args.n_gpu_layers)
    if args.n_ctx:
        os.environ["HUDDLE_N_CTX"] = str(args.n_ctx)
    if args.n_batch:
        os.environ["HUDDLE_N_BATCH"] = str(args.n_batch)
    if args.n_threads:
        os.environ["HUDDLE_N_THREADS"] = str(args.n_threads)
    
    print("🚀 Starting HuddleAI GGUF Server...")
    print(f"✅ GGUF Support: {LLAMA_CPP_AVAILABLE}")
    print(f"✅ PyTorch Support: {TORCH_AVAILABLE}")
    print(f"📖 Documentation: http://localhost:{args.port}/docs")
    
    uvicorn.run(
        "optimized_gguf_server:app",
        host=args.host,
        port=args.port,
        reload=False,
        workers=1,
        log_level="info"
    ) 