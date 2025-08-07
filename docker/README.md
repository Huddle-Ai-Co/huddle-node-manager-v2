# HNM Multi-OS Docker Testing

This directory contains Docker-based testing environments for Huddle Node Manager (HNM) across multiple operating systems and architectures.

## Quick Start

```bash
# Build all core environments
hnm docker build

# Interactive OS selection
hnm docker interactive

# Build specific OS
hnm docker build ubuntu22
hnm docker build alpine arm64
```

## Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Docker Buildx plugin (for multi-architecture builds)
- 4GB+ free disk space

Auto-check and install prerequisites:
```bash
hnm docker build  # Will check and offer to install prerequisites
```

## Usage Examples

### 1. Manual Testing (Interactive)

For hands-on testing and debugging:

```bash
# Run with proper volume mount (note :rw for write access)
docker run --rm -it \
  -v $(pwd)/..:/home/huddle/huddle-node-manager:rw \
  hnm-ubuntu22-amd64

# Inside container:
cd ~/huddle-node-manager && ./install-hnm.sh
~/test-install.sh
```

**⚠️ Important**: Always use `:rw` on volume mounts for installation testing. The default read-only mount will cause "Read-only file system" errors.

### 2. Automated Testing

For CI/CD and batch testing:

```bash
# Test specific environment
hnm docker test ubuntu22 amd64

# Test all environments
hnm docker test
```

### 3. Development Mode

For persistent development containers:

```bash
# Start persistent container
docker run -d --name hnm-dev \
  -v $(pwd)/..:/home/huddle/huddle-node-manager:rw \
  hnm-ubuntu22-amd64 tail -f /dev/null

# Work in container
docker exec -it hnm-dev bash

# Clean up when done
docker stop hnm-dev && docker rm hnm-dev
```

### 4. Specialized Environments

Test macOS, Windows (MinGW), or WSL simulation:

```bash
hnm docker build macos amd64
docker run --rm -it \
  -v $(pwd)/..:/home/huddle/huddle-node-manager:rw \
  hnm-macos-amd64
```

## Available Operating Systems

### Real Operating Systems
- **Ubuntu**: 20.04, 22.04, 24.04
- **Debian**: 11, 12
- **CentOS**: Stream 9
- **Rocky Linux**: 9
- **Alpine Linux**: 3.18, 3.19
- **Fedora**: 39, 40
- **openSUSE**: 15.5
- **Arch Linux**: Latest
- **Amazon Linux**: 2023

### Environment Simulations
- **macOS**: Fake Darwin environment with Homebrew simulation
- **MinGW**: Git Bash/MSYS2 simulation for Windows
- **WSL**: Windows Subsystem for Linux simulation

## Architectures

- **amd64** (x86_64): Standard Intel/AMD 64-bit
- **arm64** (Apple Silicon): ARM 64-bit (M1/M2 Macs, ARM servers)
- **arm** (ARM v7): 32-bit ARM devices

## Container Features

### Environment Simulation
- OS-specific package managers
- Fake system commands (uname, open, etc.)
- Platform-appropriate environment variables
- Realistic directory structures

### Testing Tools
- Pre-installed development tools
- API testing utilities
- Performance benchmarking
- Installation verification scripts

### Security
- Non-root user (huddle)
- Sudo access for system operations
- Isolated environments
- No sensitive data persistence

## Troubleshooting

### Common Issues

#### 1. "Read-only file system" errors
**Cause**: Volume mount is read-only by default
**Solution**: Add `:rw` to volume mount:
```bash
-v $(pwd)/..:/home/huddle/huddle-node-manager:rw
```

#### 2. "Permission denied" for /usr/local/opt
**Cause**: Container user lacks permissions for system directories
**Solution**: Run as intended user (already configured in containers)

#### 3. "Docker daemon not running"
**Cause**: Docker Desktop not started
**Solution**:
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

#### 4. "Input/output error" on binary execution
**Cause**: Architecture mismatch or incomplete installation
**Solution**: 
- Check if target architecture matches host
- Use QEMU for cross-platform builds
- Ensure installation completed successfully

### Debug Container Issues

```bash
# Check container logs
docker logs hnm-ubuntu22-amd64

# Debug with shell access
docker run --rm -it --entrypoint /bin/bash hnm-ubuntu22-amd64

# Check mounted volumes
docker run --rm -it hnm-ubuntu22-amd64 ls -la /home/huddle/
```

## Architecture

### Container Structure
```
/home/huddle/
├── huddle-node-manager/     # Mounted from host
├── .local/bin/              # User binaries
├── .local/lib/              # Libraries
├── entrypoint.sh            # Environment setup
└── test-install.sh          # Installation test
```

### Build Process
1. **Base Image**: OS-specific official images
2. **Dependencies**: Install build tools and dependencies
3. **User Setup**: Create non-root user with sudo
4. **Environment**: Configure OS-specific environment
5. **Entrypoint**: Set up simulation and testing tools

### Multi-Architecture
- Uses Docker Buildx for cross-platform builds
- QEMU emulation for non-native architectures
- Platform-specific optimizations

## Integration with Main Installer

The main installer (`install-hnm.sh`) includes light integration:

```bash
✅ HNM installed successfully!
🐳 Developers: Test across multiple OS with: cd docker && ./build-test-environments.sh interactive
```

This maintains separation between end-user simplicity and developer tooling.

## Performance Notes

- **Build Time**: 2-5 minutes per environment
- **Disk Usage**: ~500MB per container
- **Memory**: 512MB-1GB per running container
- **Cross-platform**: Slower on non-native architectures (QEMU)

## Contributing

When adding new operating systems:

1. Add OS to `get_os_image()` function
2. Create appropriate package manager commands
3. Update validation functions
4. Test across all supported architectures
5. Update this documentation

See `build-test-environments.sh` for implementation details. 