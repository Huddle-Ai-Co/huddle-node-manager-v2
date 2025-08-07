# H100 GPU Inference Architecture Flowchart

```mermaid
flowchart TD
    %% Client and API Management
    Client[Client Applications] --> APIM[Azure API Management]
    APIM -->|Subscription Key Auth| HuddleAPI[HuddleAI API Wrapper\nPort 8000]
    
    %% API Layer
    HuddleAPI -->|System Prompt Injection| vLLM[vLLM OpenAI API\nPort 5005]
    
    %% Ray Cluster
    subgraph RayCluster["Ray Cluster (Distributed Computing)"]
        RayHead[Ray Head Node\n10.0.0.4\nDashboard: 8265] <-->|Coordination| RayWorker[Ray Worker Node\n10.0.0.5]
        
        subgraph Node1["H100 Node 1 (huddleai-h100-node-1)"]
            vLLM --> GPU1[H100 GPU\n95GB VRAM]
            vLLM --> NVMe1[NVMe Storage\n3.5TB]
        end
        
        subgraph Node2["H100 Node 2"]
            vLLM2[vLLM Instance] --> GPU2[H100 GPU\n95GB VRAM]
            vLLM2 --> NVMe2[NVMe Storage\n3.5TB]
        end
        
        RayHead --- Node1
        RayWorker --- Node2
    end
    
    %% Storage
    subgraph SharedStorage["Shared Storage"]
        ModelStorage[Model Storage\n1TB Disk\n/mnt/models]
    end
    
    Node1 --> ModelStorage
    Node2 --> ModelStorage
    
    %% Development
    JupyterLab[JupyterLab\nPort 8889] --> ModelStorage
    
    %% Data Flow
    Client -->|1. Request| APIM
    APIM -->|2. Forward Request| HuddleAPI
    HuddleAPI -->|3. Process Request| vLLM
    vLLM -->|4. Distributed Inference| RayCluster
    RayCluster -->|5. Response| vLLM
    vLLM -->|6. Format Response| HuddleAPI
    HuddleAPI -->|7. Return Response| APIM
    APIM -->|8. Deliver Response| Client
    
    %% Styling
    classDef azure fill:#0072C6,color:white,stroke:#0072C6,stroke-width:2px;
    classDef gpu fill:#76B900,color:white,stroke:#76B900,stroke-width:2px;
    classDef storage fill:#FF8C00,color:white,stroke:#FF8C00,stroke-width:2px;
    classDef api fill:#7B68EE,color:white,stroke:#7B68EE,stroke-width:2px;
    
    class APIM azure;
    class GPU1,GPU2 gpu;
    class ModelStorage,NVMe1,NVMe2 storage;
    class HuddleAPI,vLLM,vLLM2 api;
```

## Architecture Components

### Client Layer
- **Client Applications**: Desktop apps, web interfaces, and API consumers
- **Azure API Management**: Handles rate limiting, subscription management, and authentication

### API Layer
- **HuddleAI API Wrapper**: Custom service that adds system prompts and manages request formatting
- **vLLM OpenAI API**: Provides OpenAI-compatible endpoints for LLM inference

### Compute Layer
- **Ray Cluster**: Distributed computing framework managing resources across nodes
  - **Head Node (10.0.0.4)**: Coordinates the cluster and runs inference
  - **Worker Node (10.0.0.5)**: Provides additional compute resources
- **H100 GPUs**: High-performance compute for model inference (95GB VRAM each)
- **NVMe Storage**: Fast local storage for inference caching and temporary files

### Storage Layer
- **Shared Model Storage**: 1TB disk mounted at `/mnt/models` across all nodes
- **Symbolic Links**: Efficient model file sharing between different paths

### Development Layer
- **JupyterLab**: Development environment with direct access to model files

## Data Flow Sequence

1. Client sends request to Azure API Management
2. APIM authenticates via subscription key and forwards to HuddleAI API
3. HuddleAI API adds system prompts and formats the request
4. Request is sent to vLLM OpenAI-compatible API
5. vLLM distributes inference across the Ray cluster
6. Ray coordinates tensor parallelism across H100 GPUs
7. Results are returned to vLLM and formatted
8. Response flows back through the API layers to the client

## Optimization Features

- **Tensor Parallelism**: Models distributed across multiple GPUs
- **Fast Storage**: NVMe drives for caching and temporary storage
- **Shared Models**: Symbolic links for efficient model sharing
- **Memory Optimization**: 90% GPU memory utilization setting
- **Network Optimization**: NCCL environment variables for efficient GPU communication 