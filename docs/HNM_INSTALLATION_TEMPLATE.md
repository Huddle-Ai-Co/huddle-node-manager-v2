# HNM Installation Directory Template

## 🏠 Complete HNM Installation Directory Structure

### 📍 USER HOME: `/Users/tangj4`

```
🏠 USER HOME: /Users/tangj4
├── .hnm/ (HNM_HOME - Runtime)
│   ├── config.json (User runtime config)
│   └── logs/ (Runtime logs)
│
├── .huddle-node-manager/ (PRODUCTION_ROOT - Models)
│   ├── bundled_models/ (AI Models)
│   │   ├── llama-3.2-3b-quantized-q4km/
│   │   ├── florence-2-large/
│   │   ├── whisper/
│   │   ├── surya-ocr/
│   │   ├── metricgan-plus-voicebank/
│   │   ├── NeuroKit/
│   │   └── yoloe_11l.pt
│   ├── argv.json (VS Code config)
│   └── extensions/ (VS Code extensions)
│
├── .local/
│   ├── bin/hnm (Main command)
│   ├── lib/huddle-node-manager/ (PRODUCTION_LIBRARY - Scripts)
│   │   ├── api_key_manager.sh
│   │   ├── ipfs-cluster-manager.sh
│   │   ├── ipfs-content-manager.sh
│   │   ├── ipfs-daemon-manager.sh
│   │   ├── ipfs-search-manager.sh
│   │   ├── ipfs-troubleshoot-manager.sh
│   │   ├── open-ipfs-webui.sh
│   │   ├── run_hnm_script.sh
│   │   ├── device_config.json
│   │   └── scripts/ (PYTHON_SCRIPTS)
│   │       ├── optimized_gguf_server.py
│   │       ├── optimized_resource_server.py
│   │       ├── platform_adaptive_config.py
│   │       ├── resource_monitor.py
│   │       ├── vllm_style_optimizer.py
│   │       ├── device_detection_test.py
│   │       ├── setup_*.py files
│   │       ├── verify_installation.py
│   │       ├── model_config.json
│   │       └── platform_config.json
│   └── share/doc/huddle-node-manager/ (Documentation)
│
└── .config/huddle-node-manager/ (System Config)

📁 DEVELOPMENT: /Users/tangj4/Downloads/huddle-node-manager/
   (Source code and development files)
```

## 🎯 Directory Purposes

### 📁 `~/.hnm/` (HNM_HOME - Runtime)
- **Purpose:** User-specific runtime data
- **Created by:** `hnm setup`
- **Contains:** 
  - `config.json` - User runtime configuration
  - `logs/` - Runtime logs
- **Why:** Each user has their own HNM runtime

### 📁 `~/.huddle-node-manager/` (PRODUCTION_ROOT - Models)
- **Purpose:** AI models and production data
- **Created by:** `install-hnm-complete.sh`
- **Contains:**
  - `bundled_models/` - AI models (LLaMA, Whisper, etc.)
  - `argv.json` - VS Code configuration
  - `extensions/` - VS Code extensions
- **Why:** Large model files need separate location

### 📁 `~/.local/bin/hnm` (Main Command)
- **Purpose:** Main HNM command interface
- **Created by:** `install-hnm-complete.sh`
- **Contains:** HNM command script
- **Why:** User-installed executable in PATH

### 📁 `~/.local/lib/huddle-node-manager/` (PRODUCTION_LIBRARY - Scripts)
- **Purpose:** Executable scripts and libraries
- **Created by:** `install-hnm-complete.sh`
- **Contains:**
  - Shell managers (IPFS, API keys, etc.)
  - `run_hnm_script.sh` - Python script runner
  - `device_config.json` - Device configuration
  - `scripts/` - Python scripts
- **Why:** Shared across all users, but user-installed

### 📁 `~/.local/lib/huddle-node-manager/scripts/` (PYTHON_SCRIPTS)
- **Purpose:** Python scripts and utilities
- **Created by:** `install-hnm-complete.sh`
- **Contains:**
  - AI model servers
  - Device detection
  - Resource monitoring
  - Setup and verification scripts
  - Configuration files
- **Why:** Python scripts need separate organization

### 📁 `~/.local/share/doc/huddle-node-manager/` (Documentation)
- **Purpose:** Documentation files
- **Created by:** `install-hnm-complete.sh`
- **Contains:** Currently empty (for future use)
- **Why:** User-installed documentation

### 📁 `~/.config/huddle-node-manager/` (System Config)
- **Purpose:** System-wide configuration
- **Created by:** `install-hnm-complete.sh`
- **Contains:** Currently empty (for future use)
- **Why:** System-level settings

### 📁 `/Users/tangj4/Downloads/huddle-node-manager/` (Development)
- **Purpose:** Source code and development files
- **Contains:** Project files, installers, documentation
- **Why:** Development workspace

## 🔧 Installation Flow

### 1. **Installation** (`install-hnm-complete.sh`)
```bash
# Creates all production directories
~/.huddle-node-manager/          # Models
~/.local/lib/huddle-node-manager/ # Scripts
~/.local/bin/hnm                 # Command
~/.config/huddle-node-manager/   # Config
~/.local/share/doc/huddle-node-manager/ # Docs
```

### 2. **Setup** (`hnm setup`)
```bash
# Creates runtime directories
~/.hnm/config.json              # Runtime config
~/.hnm/logs/                   # Runtime logs
```

### 3. **Usage**
```bash
hnm start                       # Uses daemon manager
hnm keys setup                  # Uses API key manager
hnm script verify_installation.py # Uses script runner
```

## ✅ FHS Compliance

This structure follows the **Filesystem Hierarchy Standard (FHS)**:

- **`~/.local/`** = User-installed software
- **`~/.config/`** = User configuration
- **`~/.hnm/`** = Application runtime data
- **`~/.local/share/doc/`** = User documentation

## 🎯 Key Benefits

1. **✅ Separation of Concerns:** Models, scripts, configs, and runtime are separate
2. **✅ User-Level Installation:** No system-wide files
3. **✅ FHS Compliant:** Follows standard directory structure
4. **✅ Development Isolation:** Development files separate from production
5. **✅ Scalable:** Easy to add new components
6. **✅ Maintainable:** Clear organization and purpose

## 🔍 Verification Commands

```bash
# Check all HNM directories
find ~ -name "*huddle*" -type d

# Check installed command
which hnm

# Check runtime config
ls -la ~/.hnm/

# Check production scripts
ls -la ~/.local/lib/huddle-node-manager/

# Check models
ls -la ~/.huddle-node-manager/bundled_models/
``` 