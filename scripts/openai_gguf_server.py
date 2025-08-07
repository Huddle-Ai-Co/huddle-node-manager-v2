#!/usr/bin/env python3
"""
OpenAI Resource Server
Provides OpenAI-compatible API endpoints using Azure OpenAI API
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
from dotenv import load_dotenv
from openai import AzureOpenAI
import httpx

# Add parent directory to sys.path for imports
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))
sys.path.insert(0, str(current_dir))

# Load environment variables from .env.local and .env files
load_dotenv('.env.local')  # Load .env.local first (higher priority)
load_dotenv('.env')        # Load .env as fallback

# Configure logging
import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Azure OpenAI Configuration from environment variables
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_4O_ENDPOINT") or os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_API_KEY = os.getenv("AZURE_OPENAI_4O_API_KEY") or os.getenv("AZURE_OPENAI_API_KEY")
AZURE_OPENAI_DEPLOYMENT = os.getenv("OPENAI_4O_MODEL") or os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")
AZURE_OPENAI_API_VERSION = os.getenv("OPENAI_4O_API_VERSION") or os.getenv("AZURE_OPENAI_API_VERSION", "2023-12-01-preview")

# Remove mock response support
# import uuid
# import time
# from datetime import datetime

# Set to False to use real Azure OpenAI API
# USE_MOCK_RESPONSES = False

# At the beginning of the file, after imports
# Check for Azure OpenAI credentials
api_key = os.getenv("AZURE_OPENAI_API_KEY") or os.getenv("AZURE_OPENAI_4O_API_KEY")
endpoint = os.getenv("AZURE_OPENAI_ENDPOINT") or os.getenv("AZURE_OPENAI_4O_ENDPOINT")

if not api_key or not endpoint:
    logger.error("❌ Missing required Azure OpenAI credentials!")
    logger.error("Please set AZURE_OPENAI_4O_ENDPOINT and AZURE_OPENAI_4O_API_KEY in .env.local or .env")
    raise ValueError("Missing Azure OpenAI credentials")
else:
    logger.info(f"✅ Azure OpenAI Configuration Loaded:")
    logger.info(f"   • Endpoint: {endpoint}")
    logger.info(f"   • API Key: {'*' * 20}...{api_key[-4:] if api_key else 'NOT SET'}")

async def execute_tools_parallel(tool_calls: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Execute multiple tools in parallel"""
    import aiohttp
    import json
    
    async def execute_single_tool(tool_call: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a single tool"""
        try:
            tool_name = tool_call["function"]["name"]
            arguments = json.loads(tool_call["function"]["arguments"])
            
            # Use the existing execute_tool_endpoint logic
            if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
                return {"error": "Function tools not available"}
            
            if tool_name not in function_tools.functions:
                return {"error": f"Tool '{tool_name}' not found"}
            
            logger.info(f"🔧 Executing {tool_name} with arguments: {arguments}")
            result = function_tools.execute_function(tool_name, arguments)
            
            return {
                "tool": tool_name,
                "arguments": arguments,
                "result": result,
                "success": True
            }
        except Exception as e:
            logger.error(f"❌ Tool execution error for {tool_call.get('function', {}).get('name', 'unknown')}: {str(e)}")
            return {
                "tool": tool_call.get('function', {}).get('name', 'unknown'),
                "error": str(e),
                "success": False
            }
    
    # Execute all tools concurrently
    tasks = [execute_single_tool(tool_call) for tool_call in tool_calls]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Handle any exceptions
    final_results = []
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            final_results.append({
                "tool": tool_calls[i].get('function', {}).get('name', 'unknown'),
                "error": str(result),
                "success": False
            })
        else:
            final_results.append(result)
    
    return final_results

async def generate_response(messages, model, temperature=0.7, top_p=0.95, max_tokens=None, stream=False, tools=None, tool_choice="auto"):
    """Generate a response from the Azure OpenAI API."""
    api_key = os.getenv("AZURE_OPENAI_API_KEY") or os.getenv("AZURE_OPENAI_4O_API_KEY")
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT") or os.getenv("AZURE_OPENAI_4O_ENDPOINT")
    api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview")
    
    if not api_key or not endpoint:
        raise ValueError("Azure OpenAI API key and endpoint must be set")
    
    # Construct the API URL
    url = f"{endpoint}/openai/deployments/{model}/chat/completions?api-version={api_version}"
    
    # Prepare the request payload
    payload = {
        "messages": messages,
        "temperature": temperature,
        "top_p": top_p,
        "stream": stream
    }
    
    if max_tokens:
        payload["max_tokens"] = max_tokens
    
    # Add tools if provided
    if tools:
        payload["tools"] = tools
        
        # Add tool_choice if provided (can be "auto", "none", or a specific tool)
        if tool_choice:
            payload["tool_choice"] = tool_choice
    
    headers = {
        "Content-Type": "application/json",
        "api-key": api_key
    }
    
    try:
        async with httpx.AsyncClient() as client:
            if stream:
                # Handle streaming response
                async with client.stream("POST", url, json=payload, headers=headers) as response:
                    response.raise_for_status()
                    async for line in response.aiter_lines():
                        if line.strip():
                            if line.startswith("data: "):
                                line = line[6:]  # Remove "data: " prefix
                            if line == "[DONE]":
                                break
                            try:
                                chunk = json.loads(line)
                                yield chunk
                            except json.JSONDecodeError:
                                logger.error(f"Failed to parse JSON: {line}")
            else:
                # Handle non-streaming response
                response = await client.post(url, json=payload, headers=headers)
                response.raise_for_status()
                result = response.json()
                # Use yield instead of return for consistency with the streaming case
                yield result
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error: {e}")
        error_detail = e.response.text if hasattr(e, 'response') else str(e)
        logger.error(f"Error detail: {error_detail}")
        raise
    except Exception as e:
        logger.error(f"Error generating response: {e}")
        raise

# Import platform-adaptive configuration
try:
    from platform_adaptive_config import get_platform_config
    PLATFORM_CONFIG = get_platform_config()
    print(f"🔧 Platform detected: {PLATFORM_CONFIG.get('platform', 'unknown')}")
except ImportError as e:
    print(f"⚠️ Platform adaptive config not available: {e}")
    PLATFORM_CONFIG = {"platform": "unknown"}

# Import medical RAG system (with fallback)
try:
    from medical_rag_system import MedicalRAGSystem
    MEDICAL_RAG_AVAILABLE = True
    print("✅ Medical RAG system successfully imported")
    medical_rag = MedicalRAGSystem()
except ImportError as e:
    print(f"⚠️ Medical RAG system not available: {e}")
    MEDICAL_RAG_AVAILABLE = False
    medical_rag = None

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

# Import multi-tool executor
try:
    # Try to import from the parent directory first (production version)
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from multi_tool_executor import multi_tool_executor
    MULTI_TOOL_AVAILABLE = True
    print("✅ Production-ready multi-tool executor loaded")
except ImportError as e:
    print(f"⚠️ Production multi-tool executor not available: {e}")
    MULTI_TOOL_AVAILABLE = False
    # Fall back to tool triggers
    try:
        from tool_triggers import tool_trigger_system
        TOOL_TRIGGERS_AVAILABLE = True
        print("✅ Tool triggers system loaded")
    except ImportError:
        TOOL_TRIGGERS_AVAILABLE = False
        print("⚠️ Tool triggers system not available")
        try:
            from enhanced_tool_identification import tool_integration
            TOOL_IDENTIFICATION_AVAILABLE = True
            print("✅ Enhanced tool identification system loaded")
        except ImportError:
            TOOL_IDENTIFICATION_AVAILABLE = False
            print("⚠️ Enhanced tool identification not available")
            # Try to fall back to basic enhanced_tool_selection if available
            try:
                from enhanced_tool_selection import get_enhanced_system_prompt, get_tool_selection_guidance
                TOOL_SELECTION_AVAILABLE = True
                print("✅ Using legacy enhanced tool selection")
            except ImportError:
                TOOL_SELECTION_AVAILABLE = False
                print("⚠️ Enhanced tool selection not available")
                # Define empty functions as last resort
                def get_enhanced_system_prompt(tools):
                    return ""
                def get_tool_selection_guidance(query, tools):
                    return ""

# Create Azure OpenAI client instance
azure_client = AzureOpenAI(
    api_key=AZURE_OPENAI_API_KEY,
    api_version=AZURE_OPENAI_API_VERSION,
    azure_endpoint=AZURE_OPENAI_ENDPOINT
)

# Request/Response models (same as optimized_gguf_server.py)
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
    model: str = Field(default="HuddleAI-OpenAI", description="Model name")
    messages: List[ChatMessage] = Field(..., description="List of messages in the conversation")
    max_tokens: Optional[int] = Field(default=800, description="Maximum tokens to generate")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: Optional[float] = Field(default=0.9, ge=0.0, le=1.0, description="Top-p sampling parameter")
    frequency_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Frequency penalty")
    presence_penalty: Optional[float] = Field(default=0.0, ge=-2.0, le=2.0, description="Presence penalty")
    stream: Optional[bool] = Field(default=False, description="Whether to stream the response")
    stop: Optional[List[str]] = Field(default=None, description="Stop sequences")
    user: Optional[str] = Field(default=None, description="User identifier")
    tools: Optional[List[Dict[str, Any]]] = Field(default=None, description="Available tools")
    tool_choice: Optional[str] = Field(default="auto", description="Tool choice strategy")
    
    # Medical-specific parameters
    specialty: Optional[str] = Field(default="general", description="Medical specialty context")
    user_type: Optional[str] = Field(default="doctor", description="User type: doctor, nurse, medical_student, etc.")
    urgency: Optional[str] = Field(default="normal", description="Urgency: normal, urgent, emergency")
    include_sources: Optional[bool] = Field(default=True, description="Include medical sources in response")

class HealthResponse(BaseModel):
    status: str = Field(..., description="Server status")
    model_loaded: bool = Field(..., description="Whether model is loaded")
    model_type: str = Field(..., description="Model type (openai)")
    device: str = Field(..., description="Device being used")
    uptime: float = Field(..., description="Server uptime in seconds")
    memory_usage: Dict[str, Any] = Field(..., description="Memory usage information")

class OpenAIModelManager:
    """Manages OpenAI API integration"""
    
    def __init__(self):
        self.model_type = "openai"
        self.model_path = None
        self.is_loaded = True  # Always true since we're using API
        self.load_lock = threading.Lock()
        self.start_time = time.time()
        
        # Apply environment variable overrides
        self.config = PLATFORM_CONFIG
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
            "OPENAI_TEMPERATURE": "temperature",
            "OPENAI_MAX_TOKENS": "max_tokens",
            "OPENAI_TOP_P": "top_p",
            "OPENAI_FREQUENCY_PENALTY": "frequency_penalty",
            "OPENAI_PRESENCE_PENALTY": "presence_penalty"
        }
        
        # Apply overrides if they exist in environment
        for env_var, config_key in env_overrides.items():
            if env_var in os.environ:
                value = os.environ[env_var]
                
                # Convert to appropriate type
                if config_key in ["max_tokens"]:
                    try:
                        value = int(value)
                    except ValueError:
                        print(f"⚠️ Invalid value for {env_var}: {value}. Must be an integer.")
                        continue
                elif config_key in ["temperature", "top_p", "frequency_penalty", "presence_penalty"]:
                    try:
                        value = float(value)
                    except ValueError:
                        print(f"⚠️ Invalid value for {env_var}: {value}. Must be a float.")
                        continue
                
                # Update config
                self.config[config_key] = value
                print(f"🔧 Override from environment: {config_key} = {value}")
    
    def format_chat_prompt(self, messages: List[Dict[str, str]], tools: List[Dict[str, Any]] = None) -> str:
        """Format chat prompt for OpenAI API"""
        # For OpenAI API, we don't need to format the prompt as a string
        # This is just a placeholder for compatibility with the original server
        return "OpenAI API handles message formatting internally"
    
    async def generate_response(self, messages: List[Dict[str, Any]], max_tokens: int = 800, 
                         temperature: float = None, top_p: float = None,
                         frequency_penalty: float = None, presence_penalty: float = None,
                         stop: List[str] = None, tools: List[Dict[str, Any]] = None,
                         tool_choice: Any = "auto", specialty: str = "general",
                         user_type: str = "doctor") -> Dict[str, Any]:
        """Generate response using Azure OpenAI API"""
        try:
            # Use config values if parameters are not provided
            temperature = temperature if temperature is not None else self.config.get("temperature", 0.7)
            top_p = top_p if top_p is not None else self.config.get("top_p", 0.9)
            frequency_penalty = frequency_penalty if frequency_penalty is not None else self.config.get("frequency_penalty", 0.0)
            presence_penalty = presence_penalty if presence_penalty is not None else self.config.get("presence_penalty", 0.0)
            max_tokens = max_tokens if max_tokens is not None else self.config.get("max_tokens", 800)
            
            # Check for medical RAG integration
            if MEDICAL_RAG_AVAILABLE and medical_rag:
                # Check if this is a medical query that should use RAG
                last_user_message = None
                for msg in reversed(messages):
                    if msg.get("role") == "user":
                        last_user_message = msg.get("content")
                        break
                
                if last_user_message:
                    try:
                        # Process with medical RAG
                        rag_response = await medical_rag.process_medical_query(
                            last_user_message,
                            user_type=user_type,
                            specialty=specialty
                        )
                        
                        if rag_response and "response" in rag_response:
                            # Use RAG response
                            return {
                                "success": True,
                                "response": rag_response["response"],
                                "sources": rag_response.get("sources", [])
                            }
                    except Exception as e:
                        logger.error(f"Medical RAG error: {e}")
                        # Continue with normal processing
            
            # Check for enhanced system prompt
            if tools:
                enhanced_prompt = None
                try:
                    if TOOL_IDENTIFICATION_AVAILABLE:
                        enhanced_prompt = tool_integration.enhance_system_prompt(tools)
                        logger.info("Using enhanced system prompt for tool selection")
                    elif TOOL_SELECTION_AVAILABLE:
                        enhanced_prompt = get_enhanced_system_prompt(tools)
                        logger.info("Using legacy enhanced system prompt for tool selection")
                except Exception as e:
                    logger.error(f"Enhanced system prompt error: {e}")
                
                if enhanced_prompt:
                    # Check if there's already a system message
                    has_system = False
                    for msg in messages:
                        if msg.get("role") == "system":
                            # Append to existing system message
                            msg["content"] = msg.get("content", "") + "\n\n" + enhanced_prompt
                            has_system = True
                            break
                    
                    if not has_system:
                        # Add as first message
                        messages.insert(0, {
                            "role": "system",
                            "content": enhanced_prompt
                        })
            
            # Handle tool_choice parameter
            api_tool_choice = tool_choice
            if isinstance(tool_choice, dict) and "function" in tool_choice.get("type", ""):
                # Format tool_choice for the API
                api_tool_choice = {
                    "type": "function",
                    "function": {"name": tool_choice.get("function", {}).get("name", "")}
                }
                logger.info(f"Using specific tool choice: {api_tool_choice}")
            
            # Generate response using Azure OpenAI API
            completion = azure_client.chat.completions.create(
                model=AZURE_OPENAI_DEPLOYMENT,
                messages=messages,
                temperature=temperature,
                top_p=top_p,
                frequency_penalty=frequency_penalty,
                presence_penalty=presence_penalty,
                max_tokens=max_tokens,
                stop=stop,
                tools=tools,
                tool_choice=api_tool_choice
            )
            
            # Extract response content
            response_message = completion.choices[0].message
            response_content = response_message.content or ""
            
            # Check for tool calls
            tool_calls = None
            if hasattr(response_message, 'tool_calls') and response_message.tool_calls:
                tool_calls = []
                for tool_call in response_message.tool_calls:
                    tool_calls.append({
                        "id": tool_call.id,
                        "type": tool_call.type,
                        "function": {
                            "name": tool_call.function.name,
                            "arguments": tool_call.function.arguments
                        }
                    })
                    
                    # Execute tool calls if function tools are available
                    if FUNCTION_TOOLS_AVAILABLE and function_tools:
                        try:
                            # Parse arguments
                            arguments = json.loads(tool_call.function.arguments)
                            
                            # Execute function
                            result = function_tools.execute_function(tool_call.function.name, arguments)
                            
                            # Add result to tool call
                            tool_calls[-1]["function"]["result"] = json.dumps(result) if isinstance(result, (dict, list)) else str(result)
                        except Exception as e:
                            logger.error(f"Error executing function {tool_call.function.name}: {e}")
                            tool_calls[-1]["function"]["result"] = json.dumps({"error": str(e)})
            
            return {
                "success": True,
                "response": response_content,
                "tool_calls": tool_calls
            }
            
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def generate_stream(self, messages: List[Dict[str, Any]], max_tokens: int = 800, 
                       temperature: float = None, top_p: float = None,
                       frequency_penalty: float = None, presence_penalty: float = None,
                       stop: List[str] = None, tools: List[Dict[str, Any]] = None,
                       tool_choice: str = "auto") -> AsyncGenerator[str, None]:
        """Generate streaming response using Azure OpenAI API"""
        try:
            # Set default parameters if not provided
            temperature = temperature if temperature is not None else self.config.get("temperature", 0.7)
            top_p = top_p if top_p is not None else self.config.get("top_p", 0.9)
            frequency_penalty = frequency_penalty if frequency_penalty is not None else self.config.get("frequency_penalty", 0.0)
            presence_penalty = presence_penalty if presence_penalty is not None else self.config.get("presence_penalty", 0.0)
            
            # Call Azure OpenAI API with streaming
            response = azure_client.chat.completions.create(
                model=AZURE_OPENAI_DEPLOYMENT,
                messages=messages,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                frequency_penalty=frequency_penalty,
                presence_penalty=presence_penalty,
                stop=stop,
                tools=tools,
                tool_choice=tool_choice if tools else None,
                stream=True
            )
            
            # Stream the response
            for chunk in response:
                if chunk.choices and chunk.choices[0].delta:
                    delta = chunk.choices[0].delta
                    
                    # Format chunk as OpenAI-compatible streaming response
                    chunk_data = {
                        "id": f"chatcmpl-{int(time.time())}",
                        "object": "chat.completion.chunk",
                        "created": int(time.time()),
                        "model": AZURE_OPENAI_DEPLOYMENT,
                        "choices": [{
                            "index": 0,
                            "delta": {},
                            "finish_reason": chunk.choices[0].finish_reason
                        }]
                    }
                    
                    # Add content if present
                    if hasattr(delta, "content") and delta.content is not None:
                        chunk_data["choices"][0]["delta"]["content"] = delta.content
                    
                    # Add role if present
                    if hasattr(delta, "role") and delta.role is not None:
                        chunk_data["choices"][0]["delta"]["role"] = delta.role
                    
                    # Add tool calls if present
                    if hasattr(delta, "tool_calls") and delta.tool_calls:
                        chunk_data["choices"][0]["delta"]["tool_calls"] = [
                            {
                                "id": tc.id,
                                "type": tc.type,
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments
                                }
                            }
                            for tc in delta.tool_calls
                        ]
                    
                    yield f"data: {json.dumps(chunk_data)}\n\n"
            
            # Send final [DONE] message
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            logger.error(f"Error generating streaming response with OpenAI: {e}")
            error_chunk = {
                "error": {
                    "message": f"Streaming error: {str(e)}",
                    "type": "openai_streaming_error"
                }
            }
            yield f"data: {json.dumps(error_chunk)}\n\n"
    
    def execute_function_calls(self, tool_calls: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Execute function calls from OpenAI response"""
        if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
            return [{"error": "Function tools not available"}]
        
        results = []
        
        for tool_call in tool_calls:
            try:
                function_name = tool_call["function"]["name"]
                arguments = json.loads(tool_call["function"]["arguments"])
                
                # Execute function
                result = function_tools.execute_function(function_name, arguments)
                
                # Format result
                results.append({
                    "tool_call_id": tool_call["id"],
                    "role": "tool",
                    "name": function_name,
                    "content": json.dumps(result) if isinstance(result, (dict, list)) else str(result)
                })
            except Exception as e:
                results.append({
                    "tool_call_id": tool_call["id"],
                    "role": "tool",
                    "name": tool_call["function"]["name"],
                    "content": json.dumps({"error": str(e)})
                })
        
        return results
    
    def get_memory_info(self) -> Dict[str, Any]:
        """Get memory usage information"""
        process = psutil.Process(os.getpid())
        memory_info = process.memory_info()
        
        return {
            "rss": memory_info.rss / (1024 * 1024),  # RSS in MB
            "vms": memory_info.vms / (1024 * 1024),  # VMS in MB
            "percent": process.memory_percent(),
            "available": psutil.virtual_memory().available / (1024 * 1024)  # Available memory in MB
        }

# Initialize the model manager
model_manager = OpenAIModelManager()

# FastAPI app
app = FastAPI(
    title="HuddleAI OpenAI Server",
    description="OpenAI-compatible API server using Azure OpenAI",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint with documentation"""
    return HTMLResponse(content="""
    <html>
        <head>
            <title>HuddleAI OpenAI Server</title>
            <style>
                body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { color: #333; }
                pre { background-color: #f5f5f5; padding: 10px; border-radius: 5px; }
                .endpoint { margin-bottom: 20px; }
            </style>
        </head>
        <body>
            <h1>HuddleAI OpenAI Server</h1>
            <p>OpenAI-compatible API server using Azure OpenAI</p>
            <div class="endpoint">
                <h2>Endpoints:</h2>
                <ul>
                    <li><a href="/docs">/docs</a> - Interactive API documentation</li>
                    <li><a href="/health">/health</a> - Health check endpoint</li>
                    <li><a href="/model/info">/model/info</a> - Model information</li>
                </ul>
            </div>
        </body>
    </html>
    """)

@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    uptime = time.time() - model_manager.start_time
    memory_usage = model_manager.get_memory_info()
    
    return {
        "status": "healthy",
        "model_loaded": model_manager.is_loaded,
        "model_type": model_manager.model_type,
        "device": "azure",
        "uptime": uptime,
        "memory_usage": memory_usage
    }

@app.post("/v1/chat/completions")
async def create_chat_completion_endpoint(request: ChatCompletionRequest):
    """OpenAI-compatible chat completions endpoint."""
    try:
        # Convert Pydantic model messages to dict if needed
        if hasattr(request.messages[0], "dict"):
            messages = [msg.dict() if hasattr(msg, "dict") else msg for msg in request.messages]
        else:
            messages = request.messages
            
        model = request.model
        temperature = request.temperature
        max_tokens = request.max_tokens
        stream = request.stream
        top_p = request.top_p
        
        # Default tool_choice to "auto"
        tool_choice = "auto"
        enhanced_tools = request.tools
        
        # Check for enhanced tool selection
        try:
            # Get the last user message
            user_messages = [msg for msg in messages if msg.get("role") == "user"]
            if user_messages and request.tools:
                last_user_message = user_messages[-1].get("content", "")
                
                # Try different tool selection methods in order of preference
                if MULTI_TOOL_AVAILABLE:
                    # Use the multi-tool executor for complex queries
                    try:
                        analysis = multi_tool_executor.analyze_query(last_user_message)
                        logger.info(f"Multi-tool analysis: multi_tool={analysis.get('multi_tool', False)}, tools={[m['tool_name'] for m in analysis.get('all_matches', [])]}")
                        
                        if analysis["multi_tool"]:
                            execution_plan = analysis["execution_plan"]
                            
                            # Check if this is a parallel execution
                            if execution_plan["type"] == "parallel":
                                # Add parallel execution guidance
                                guidance = multi_tool_executor.enhance_prompt(last_user_message, request.tools)
                                if guidance:
                                    guidance_msg = {
                                        "role": "system",
                                        "content": guidance
                                    }
                                    messages.insert(0, guidance_msg)
                                    logger.info("Added parallel multi-tool execution guidance")
                                
                                # For parallel execution, let the model decide based on guidance
                                enhanced_tools = request.tools
                                tool_choice = "auto"
                                
                                # Add parallel execution hint
                                parallel_msg = {
                                    "role": "system",
                                    "content": "This query requires multiple tools to be executed in parallel. Execute all identified tools simultaneously and combine their results."
                                }
                                messages.insert(0, parallel_msg)
                                logger.info("Added parallel execution hint")
                                
                            elif execution_plan["type"] == "multi":
                                # Add sequential multi-tool guidance
                                guidance = multi_tool_executor.enhance_prompt(last_user_message, request.tools)
                                if guidance:
                                    guidance_msg = {
                                        "role": "system",
                                        "content": guidance
                                    }
                                    messages.insert(0, guidance_msg)
                                    logger.info("Added sequential multi-tool execution guidance")
                                
                                # For sequential execution, let the model decide based on guidance
                                enhanced_tools = request.tools
                                tool_choice = "auto"
                            else:
                                # Fall back to single tool handling
                                if analysis["all_matches"]:
                                    tool_name = analysis["all_matches"][0]["tool_name"]
                                    tool_choice = {"type": "function", "function": {"name": tool_name}}
                                    logger.info(f"Forcing single tool choice: {tool_name}")
                        else:
                            # Fall back to single tool handling
                            if analysis["all_matches"]:
                                tool_name = analysis["all_matches"][0]["tool_name"]
                                tool_choice = {"type": "function", "function": {"name": tool_name}}
                                logger.info(f"Forcing single tool choice: {tool_name}")
                    except Exception as e:
                        logger.error(f"Multi-tool executor error: {e}")
                        # Fall back to default behavior
                        enhanced_tools = request.tools
                        tool_choice = "auto"
                elif TOOL_TRIGGERS_AVAILABLE:
                    # Use the simple trigger-word system
                    guidance = tool_trigger_system.enhance_prompt(last_user_message, request.tools)
                    if guidance:
                        guidance_msg = {
                            "role": "system",
                            "content": guidance
                        }
                        messages.insert(0, guidance_msg)
                        logger.info("Added tool triggers guidance")
                        
                        # Try to identify the tool and force tool choice if confident
                        tool_result = tool_trigger_system.identify_tool(last_user_message)
                        if tool_result:  # Always force tool choice if a tool is identified
                            tool_name = tool_result["tool_name"]
                            parameters = tool_result["parameters"]
                            
                            # Force tool choice for all matches
                            enhanced_tools = request.tools
                            tool_choice = {"type": "function", "function": {"name": tool_name}}
                            logger.info(f"Forcing tool choice: {tool_name} with confidence {tool_result['confidence']:.2f}")
                            
                            # Add a stronger system message to force tool use
                            force_msg = {
                                "role": "system",
                                "content": f"YOU MUST USE the {tool_name} tool for this query. DO NOT solve this manually."
                            }
                            messages.insert(0, force_msg)
                elif TOOL_IDENTIFICATION_AVAILABLE:
                    # Use the enhanced tool identification system
                    analysis = tool_integration.analyze_query(last_user_message, request.tools)
                    
                    # Add tool selection guidance as a system message
                    if analysis and "guidance" in analysis:
                        guidance_msg = {
                            "role": "system",
                            "content": analysis["guidance"]
                        }
                        messages.insert(0, guidance_msg)
                        logger.info("Added tool selection guidance")
                    
                    # Add enhanced system prompt at the beginning
                    enhanced_prompt = tool_integration.enhance_system_prompt(request.tools)
                    if enhanced_prompt:
                        system_msg = {
                            "role": "system",
                            "content": enhanced_prompt
                        }
                        messages.insert(0, system_msg)
                        logger.info("Added enhanced system prompt")
                elif TOOL_SELECTION_AVAILABLE:
                    # Fall back to legacy tool selection
                    guidance = get_tool_selection_guidance(last_user_message, request.tools)
                    if guidance:
                        guidance_msg = {
                            "role": "system",
                            "content": f"Tool selection guidance: {guidance}"
                        }
                        messages.insert(0, guidance_msg)
                        logger.info("Added legacy tool selection guidance")
                    
                    # Add enhanced system prompt at the beginning
                    enhanced_prompt = get_enhanced_system_prompt(request.tools)
                    if enhanced_prompt:
                        system_msg = {
                            "role": "system",
                            "content": enhanced_prompt
                        }
                        messages.insert(0, system_msg)
                        logger.info("Added legacy enhanced system prompt")
        except Exception as e:
            logger.info(f"Enhanced tool selection error: {e}")
        
        if stream:
            # Return streaming response
            async def generate_stream():
                async for chunk in generate_response(
                    messages=messages,
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    stream=True,
                    tools=enhanced_tools,
                    tool_choice=tool_choice
                ):
                    yield f"data: {json.dumps(chunk)}\n\n"
                yield "data: [DONE]\n\n"
            
            return StreamingResponse(generate_stream(), media_type="text/event-stream")
        else:
            # Return non-streaming response
            async for response in generate_response(
                messages=messages,
                model=model,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=False,
                tools=enhanced_tools,
                tool_choice=tool_choice
            ):
                # Check if response contains tool calls that need execution
                if response.get("choices") and response["choices"][0].get("message", {}).get("tool_calls"):
                    tool_calls = response["choices"][0]["message"]["tool_calls"]
                    
                    # Execute tools in parallel if possible
                    if len(tool_calls) > 1:
                        logger.info(f"🔄 Executing {len(tool_calls)} tools in parallel")
                        tool_results = await execute_tools_parallel(tool_calls)
                    else:
                        logger.info(f"🔄 Executing single tool")
                        tool_results = await execute_tools_parallel(tool_calls)
                    
                    # Add tool results to messages for final response
                    tool_result_messages = []
                    for i, tool_call in enumerate(tool_calls):
                        if i < len(tool_results):
                            result = tool_results[i]
                            tool_result_messages.append({
                                "role": "tool",
                                "tool_call_id": tool_call["id"],
                                "content": str(result.get("result", "Tool execution failed"))
                            })
                    
                    # Generate final response with tool results
                    if tool_result_messages:
                        final_messages = messages + [
                            response["choices"][0]["message"]
                        ] + tool_result_messages
                        
                        logger.info("🔄 Generating final response with tool results")
                        async for final_response in generate_response(
                            messages=final_messages,
                            model=model,
                            temperature=temperature,
                            max_tokens=max_tokens,
                            stream=False,
                            tools=enhanced_tools,
                            tool_choice="none"  # Don't call tools again
                        ):
                            return final_response
                
                return response
    except Exception as e:
        logger.error(f"Error in chat completion endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/v1/chat/completions/tool_results")
async def chat_completion_tool_results(request: Request):
    """Handle tool results from previous chat completion"""
    try:
        data = await request.json()
        
        # Extract messages and tool results
        messages = data.get("messages", [])
        
        # Generate response
        response_data = await model_manager.generate_response(
            messages=messages,
            max_tokens=data.get("max_tokens", 800),
            temperature=data.get("temperature", 0.7),
            top_p=data.get("top_p", 0.9),
            tools=data.get("tools")
        )
        
        if not response_data.get("success"):
            raise HTTPException(status_code=500, detail=response_data.get("error", "Unknown error"))
        
        # Create response
        response = {
            "id": f"chatcmpl-{int(time.time())}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": data.get("model", "HuddleAI-OpenAI"),
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_data.get("response")
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": sum(len(msg.get("content", "").split()) if msg.get("content") else 0 for msg in messages),
                "completion_tokens": len(response_data.get("response", "").split()) if response_data.get("response") else 0,
                "total_tokens": sum(len(msg.get("content", "").split()) if msg.get("content") else 0 for msg in messages) + (len(response_data.get("response", "").split()) if response_data.get("response") else 0)
            }
        }
        
        # Add tool calls if present
        if response_data.get("tool_calls"):
            response["choices"][0]["message"]["tool_calls"] = response_data["tool_calls"]
            response["choices"][0]["finish_reason"] = "tool_calls"
        
        return response
        
    except Exception as e:
        logger.error(f"Error in tool results endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/model/info")
async def model_info():
    """Get model information"""
    return {
        "model_type": "openai",
        "model_name": AZURE_OPENAI_DEPLOYMENT,
        "provider": "Azure OpenAI",
        "endpoint": AZURE_OPENAI_ENDPOINT.replace(AZURE_OPENAI_API_KEY, "***"),
        "api_version": AZURE_OPENAI_API_VERSION,
        "capabilities": {
            "chat": True,
            "streaming": True,
            "function_calling": True,
            "medical_rag": MEDICAL_RAG_AVAILABLE
        },
        "config": {
            "temperature": model_manager.config.get("temperature", 0.7),
            "max_tokens": model_manager.config.get("max_tokens", 800),
            "top_p": model_manager.config.get("top_p", 0.9)
        }
    }

@app.get("/functions")
async def list_functions():
    """List available functions"""
    if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
        return {"error": "Function tools not available"}
    
    try:
        return function_tools.get_function_definitions()
    except Exception as e:
        logger.error(f"Error listing functions: {e}")
        # Return empty list as fallback
        return []

@app.post("/api/execute_tool")
async def execute_tool_endpoint(request: Request):
    """Execute a tool directly with user permission"""
    try:
        data = await request.json()
        
        tool_name = data.get("name")
        arguments = data.get("arguments", {})
        
        if not tool_name:
            raise HTTPException(status_code=400, detail="Tool name is required")
        
        # Import function tools
        if not FUNCTION_TOOLS_AVAILABLE or not function_tools:
            raise HTTPException(status_code=500, detail="Function tools not available")
        
        # Check if tool exists
        if tool_name not in function_tools.functions:
            raise HTTPException(status_code=404, detail=f"Tool '{tool_name}' not found")
        
        # Execute the function
        logger.info(f"🔧 Directly executing {tool_name} with arguments: {arguments}")
        result = function_tools.execute_function(tool_name, arguments)
        
        return {
            "tool": tool_name,
            "arguments": arguments,
            "result": result,
            "timestamp": int(time.time())
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Tool execution error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Tool execution failed: {str(e)}")

def main():
    """Run the server"""
    import argparse
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="OpenAI-compatible server using Azure OpenAI API")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8002, help="Port to bind to")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload")
    
    args = parser.parse_args()
    
    # Get port from environment variable if set
    port = int(os.environ.get("PORT", args.port))
    
    # Run the server
    uvicorn.run(
        "openai_gguf_server:app",
        host=args.host,
        port=port,
        reload=args.reload
    )

if __name__ == "__main__":
    main() 