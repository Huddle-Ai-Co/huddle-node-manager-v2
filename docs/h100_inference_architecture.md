# H100 GPU Inference Architecture Documentation

## Overview
This document outlines the architecture of our AI inference system running on NVIDIA H100 GPUs. The system is designed for high-performance, scalable inference using vLLM and Ray, with a custom API wrapper for seamless integration with client applications.

## Hardware Configuration

### GPU Resources
- **Primary Compute**: 2x NVIDIA H100 NVL GPUs with 95GB VRAM each
- **Current Usage**: ~86GB VRAM in use for model serving

### Storage Configuration
- **Model Storage**: 1TB attached disk mounted at `/mnt/models/` (89% used, 112GB available)
- **Fast Inference Storage**: 3.5TB NVMe drive mounted at `/mnt/nvme/` (mostly empty, 3.3TB available)
- **Working Directory**: 126GB disk mounted at `/mnt/` (18% used)
- **System Disk**: 29GB root disk (87% used)

## Software Stack

### Model Serving Layer
- **vLLM**: Running as a standalone process (not a systemd service)
- **Command**: 
  ```
  python -m vllm.entrypoints.openai.api_server \
    --model /mnt/models/Llama-3.2-3B-Instruct \
    --host 0.0.0.0 \
    --port 5005 \
    --max-model-len 4096 \
    --gpu-memory-utilization 0.9 \
    --trust-remote-code \
    --chat-template /mnt/models/Llama-3.2-3B-Instruct/chat_template.jinja
  ```
- **Environment**: Custom Python environment at `/mnt/work/vllm_env/`

### API Layer
- **HuddleAI API Wrapper**: Running as a systemd service (`huddleai_api.service`)
- **Service Configuration**:
  ```
  [Unit]
  Description=HuddleAI API Wrapper
  After=network.target

  [Service]
  User=azureuser
  WorkingDirectory=/home/azureuser/huddleai_api
  ExecStart=/home/azureuser/miniconda/bin/python /home/azureuser/huddleai_api/huddleai_api_wrapper.py --host 0.0.0.0 --port 8000
  Restart=always
  RestartSec=10
  StandardOutput=journal
  StandardError=journal
  SyslogIdentifier=huddleai-api

  [Install]
  WantedBy=multi-user.target
  ```
- **API Functionality**:
  - Listens on port 8000
  - Forwards requests to the vLLM server at `http://localhost:5005/v1/chat/completions`
  - Adds custom system prompts and handles request/response formatting

### Orchestration with Ray
- **Ray**: Used for distributed computing and resource management across multiple nodes
- **Multi-Node Configuration**:
  - Multiple Ray sessions running simultaneously (three GCS servers visible)
  - Ray head node configuration with dashboard on port 8265
  - Worker nodes connect to the head node via `ray://[head-ip]:10001`
  - Node resources properly tagged with GPU counts and node types
- **vLLM Integration**:
  - vLLM uses Ray as its distributed executor backend
  - Tensor parallelism across GPUs coordinated by Ray
  - Environment variables set for network optimization:
    ```
    NCCL_SOCKET_IFNAME=eth0
    NCCL_IB_DISABLE=1
    ```
- **Resource Management**:
  - Ray manages GPU allocation across nodes
  - Handles parallel processing and workload distribution
  - Monitors available resources and schedules tasks accordingly
- **Cluster State**:
  - Current cluster shows two nodes: `10.0.0.4` (head) and `10.0.0.5` (worker)
  - Each node contributes 1 H100 GPU to the cluster
  - Ray dashboard provides real-time monitoring of cluster state

### Development Environment
- **JupyterLab**: Running on port 8889
- **Command**:
  ```
  /home/azureuser/miniconda/envs/pytorch/bin/jupyter lab \
    --no-browser \
    --ip=0.0.0.0 \
    --port=8889 \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*'
  ```
- **Working Directory**: `/mnt/models/` (provides direct access to model files)
- **Environment**: PyTorch environment for model development and testing

## Model Configuration

### Primary Model
- **Model**: Llama-3.2-3B-Instruct
- **Location**: `/mnt/models/Llama-3.2-3B-Instruct/`
- **Files**:
  - Model weights: `model-00001-of-00002.safetensors`, `model-00002-of-00002.safetensors`
  - Configuration: `config.json`, `generation_config.json`
  - Tokenizer: `tokenizer.json`, `tokenizer_config.json`
  - Templates: `chat_template.jinja`
  - Custom prompts: `system_prompt.txt`

### Symlinked Models
The system uses symbolic links to efficiently share model files across different paths:
- **HuddleAI Language Model**: `/mnt/models/huddle-ai/language/hl/`
  - Links to the Llama-3.2-3B-Instruct model files
  - Provides a custom `system_prompt.txt` and `model_info.json`

## Data Flow

1. **Client Request**: Requests come to the HuddleAI API (port 8000)
2. **Request Processing**:
   - The API wrapper adds system prompts and formats the request
   - The formatted request is forwarded to vLLM (port 5005)
3. **Inference**:
   - vLLM processes the request using the H100 GPU
   - Uses NVMe storage for fast cache access when needed
4. **Response Handling**:
   - The response is returned to the API wrapper
   - The API wrapper formats and returns the response to the client

## Multi-Node Setup

- **Node Identification**: Current node hostname is `huddleai-h100-node-1`
- **Network Configuration**: Internal IP address 10.0.0.4
- **Shared Storage**:
  - The `/mnt/models/` directory is shared across nodes
  - Symbolic links ensure consistent model access across the cluster
- **Coordination**: Ray manages the coordination between nodes

## Optimization Features

### Storage Optimization
- **Fast Inference**: NVMe storage at `/mnt/nvme/workspace/` with dedicated directories:
  - `inference_cache`: For caching inference results
  - `vllm_cache`: For vLLM-specific caching
  - `models`: For temporary model copies during optimization
  - `scratch`: For temporary processing

### Memory Utilization
- GPU memory utilization set to 90% (`--gpu-memory-utilization 0.9`)
- Maximum model context length of 4096 tokens

## Integration with Azure Services

- **API Management**: Connects to Azure API Management (APIM) via private direct connect
- **Rate Limiting**: Handled by APIM
- **Subscription Management**: Managed through APIM
- **Developer Portal**: Provides API documentation and subscription management

## Security

- **API Authentication**: Subscription keys managed by APIM
- **Service Authentication**: Internal services communicate over private network
- **Access Control**: API subscription keys used for client authentication

## Monitoring and Maintenance

- **Service Logs**: Standard output and error logs captured in systemd journal
- **Process Monitoring**: Systemd manages service restarts and failures
- **GPU Monitoring**: NVIDIA SMI provides GPU utilization and memory usage information

---

*This architecture documentation was generated based on system inspection performed on June 23, 2025.* 