# Headless Mac Setup Scripts

Modular setup scripts for configuring macOS (especially Mac Mini) for 24/7 headless operation with Ollama LLM inference and containerized workloads.

## Features

- 🔧 **Modular Architecture**: Each component (Homebrew, Power Management, Ollama, Colima) is independent
- 🎯 **Consistent Interface**: All scripts support `setup`, `enable`, `disable`, `remove`, and `status` commands
- 🤖 **Ollama-Aware**: Colima intelligently allocates resources when Ollama is running
- 🚀 **Auto-Start**: Services configured to start automatically on boot
- 💻 **Apple Silicon Optimized**: Native ARM64 support with architecture verification
- 🔐 **Safe Operations**: Backup configs before changes, confirmation prompts

## Quick Start

```bash
# Clone the repository
git clone https://github.com/miha42-github/headless-macs.git
cd headless-macs

# Make scripts executable
chmod +x setup.sh lib/common.sh scripts/*.sh

# Full setup (interactive)
./setup.sh install all

# Or use the interactive menu
./setup.sh menu

# Check status
./setup.sh status
```

## Components

### 1. Power Management
Configures macOS power settings for 24/7 operation without sleep.

```bash
./scripts/power_management.sh setup      # Configure for headless operation
./scripts/power_management.sh enable     # Apply headless settings
./scripts/power_management.sh disable    # Restore normal power settings
./scripts/power_management.sh status     # Show current settings
./scripts/power_management.sh remove     # Restore defaults and cleanup
```

**What it does:**
- Disables system sleep
- Disables disk sleep
- Enables Wake-on-LAN
- Allows display sleep (saves power)
- Backs up original settings

### 2. Homebrew
Installs and manages Homebrew package manager.

```bash
./scripts/homebrew_setup.sh setup        # Install Homebrew
./scripts/homebrew_setup.sh enable       # Add to PATH
./scripts/homebrew_setup.sh disable      # Remove from PATH
./scripts/homebrew_setup.sh status       # Show installation status
./scripts/homebrew_setup.sh remove       # Uninstall Homebrew
```

**What it does:**
- Detects correct architecture (ARM64/Intel)
- Warns if using wrong Homebrew version
- Adds to shell PATH
- Updates Homebrew

### 3. Ollama
Installs Ollama and configures it as a system service for LLM inference.

```bash
./scripts/ollama_setup.sh setup          # Install and configure Ollama
./scripts/ollama_setup.sh enable         # Start Ollama service
./scripts/ollama_setup.sh disable        # Stop Ollama service
./scripts/ollama_setup.sh status         # Show service status
./scripts/ollama_setup.sh remove         # Uninstall Ollama
```

**What it does:**
- Installs Ollama (verifies ARM64)
- Creates launchd service for auto-start
- Configures environment variables:
  - `OLLAMA_MAX_LOADED_MODELS` (default: 3)
  - `OLLAMA_KEEP_ALIVE` (default: 24 hours)
  - `OLLAMA_NUM_PARALLEL` (default: 4)
  - `OLLAMA_MAX_CONTEXT` (default: 32768)
  - `OLLAMA_HOST` (default: 0.0.0.0:11434)
- Verifies API endpoint
- Auto-starts on boot

**Next steps after setup:**
```bash
# Pull a model
ollama pull qwen2.5-coder:7b

# Test inference
ollama run qwen2.5-coder:7b "write hello world in python"

# List models
ollama list
```

### 4. Colima + Docker
Installs Colima (lightweight Docker alternative) with intelligent resource allocation.

```bash
./scripts/colima_setup.sh setup          # Install and configure Colima
./scripts/colima_setup.sh enable         # Start Colima
./scripts/colima_setup.sh disable        # Stop Colima
./scripts/colima_setup.sh status         # Show Colima status
./scripts/colima_setup.sh remove         # Remove Colima and VM
```

**What it does:**
- Installs Colima, Docker CLI, Docker Compose, Docker Buildx
- **Ollama-Aware Resource Allocation:**
  - Detects if Ollama is running
  - Calculates available RAM (Total - Ollama - System)
  - Recommends appropriate CPU/RAM allocation
- Configures for Apple Silicon:
  - Uses VZ virtualization
  - Enables Rosetta for x86_64 containers
  - Uses virtiofs for fast file mounts
  - Enables network-address for host communication
- Creates launchd service for auto-start
- Tests with hello-world container

**Container-to-Ollama connectivity:**
```bash
# Containers can reach host Ollama at:
# http://host.docker.internal:11434

# Example docker-compose.yml
services:
  app:
    image: myapp
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
```

## Master Script

The `setup.sh` master script orchestrates all components:

```bash
# Interactive menu
./setup.sh menu

# CLI commands
./setup.sh install all              # Full setup
./setup.sh install ollama           # Install only Ollama
./setup.sh enable all               # Start all services
./setup.sh disable all              # Stop all services
./setup.sh status                   # Show status of all components
./setup.sh status ollama            # Show Ollama status only
./setup.sh remove ollama            # Remove Ollama
./setup.sh remove all               # Remove everything
```

## File Structure

```
headless-macs/
├── setup.sh                        # Master orchestration script
├── lib/
│   └── common.sh                   # Shared utility functions
├── scripts/
│   ├── power_management.sh         # Power management
│   ├── homebrew_setup.sh           # Homebrew installation
│   ├── ollama_setup.sh             # Ollama setup
│   └── colima_setup.sh             # Colima + Docker
├── pmset_to_ollama.sh             # [DEPRECATED] Original script
├── setup_colima.sh                # [DEPRECATED] Original script
├── PLANNING.md                     # Refactoring plan
└── README.md                       # This file
```

## Requirements

- macOS (tested on macOS 26 Tahoe)
- Apple Silicon recommended (M1/M2/M3/M4)
- Administrator access (for system-level configurations)
- Internet connection (for downloads)

## Configuration Files

Scripts save configuration to your home directory:

- `~/.headless-mac-pmset-backup.txt` - Original power settings backup
- `~/.headless-mac-ollama-config` - Ollama configuration
- `~/.headless-mac-colima-config` - Colima configuration

## Log Files

Service logs are written to `/tmp/`:

- `/tmp/ollama.log` - Ollama stdout
- `/tmp/ollama.err` - Ollama stderr
- `/tmp/colima.log` - Colima stdout
- `/tmp/colima.err` - Colima stderr

## Launchd Services

Auto-start services are configured via launchd:

- `/Library/LaunchDaemons/com.ollama.server.plist` - Ollama (system-level)
- `~/Library/LaunchAgents/com.colima.plist` - Colima (user-level)

## Use Cases

### 1. LLM Inference Server
```bash
./setup.sh install all
ollama pull qwen2.5-coder:32b
# Server ready for 24/7 LLM inference
```

### 2. Development with Containers + LLM
```bash
./setup.sh install all
# Run containers that can access host Ollama
docker run -e OLLAMA_BASE_URL=http://host.docker.internal:11434 myapp
```

### 3. Headless Operation Only
```bash
./scripts/power_management.sh setup
./scripts/ollama_setup.sh setup
# No containers needed
```

## Troubleshooting

### Ollama not accessible from containers
```bash
# Verify Ollama is running
./scripts/ollama_setup.sh status

# Verify Colima has network-address enabled
colima status

# Test from container
docker run --rm curlimages/curl http://host.docker.internal:11434/api/tags
```

### Services not auto-starting after reboot
```bash
# Check launchd status
sudo launchctl list | grep ollama
launchctl list | grep colima

# Reload services
./scripts/ollama_setup.sh enable
./scripts/colima_setup.sh enable
```

### Power settings not persisting
```bash
# Verify settings
pmset -g

# Reapply
./scripts/power_management.sh enable

# Check for conflicting settings
sudo pmset -g custom
```

## Resource Recommendations

### Mac Mini M4 (16GB RAM)
```
Ollama: 8GB (for 7B-13B models)
Colima: 6GB
System: 2GB
```

### Mac Mini M4 (24GB RAM)
```
Ollama: 12GB (for 13B-32B models)
Colima: 10GB
System: 2GB
```

### Mac Mini M4 Pro (64GB RAM)
```
Ollama: 40GB (for 70B+ models)
Colima: 20GB
System: 4GB
```

## Comparison with Original Scripts

### Old (Deprecated)
- ❌ Monolithic scripts
- ❌ No enable/disable/remove functions
- ❌ No Ollama awareness in Colima
- ❌ Manual configuration required

### New (Current)
- ✅ Modular components
- ✅ Consistent interface (setup/enable/disable/remove/status)
- ✅ Colima aware of Ollama resources
- ✅ Master orchestration script
- ✅ Interactive menu mode
- ✅ Configuration persistence
- ✅ Safe operations with backups

## Contributing

Pull requests welcome! Please ensure:
- All scripts follow the common interface pattern
- Functions are well-documented
- Changes are tested on Apple Silicon

## License

See [LICENSE](LICENSE) file.

## Acknowledgments

Built for Mac Mini M4 headless operation with Ollama and containerized workloads.

---

**Note**: The old scripts (`pmset_to_ollama.sh` and `setup_colima.sh`) are deprecated but remain for backward compatibility. Please migrate to the new modular scripts.
