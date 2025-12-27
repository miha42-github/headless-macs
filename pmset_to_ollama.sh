#!/bin/bash

# Headless Mac Mini M4 Setup Script
# Configures power management and Ollama service for 24/7 LLM inference
# macOS 26 Tahoe compatible

set -e  # Exit on error

echo "=================================================="
echo "Headless Mac Mini M4 Setup Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${NC}[ℹ]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

# Check if running on Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    print_error "This script is designed for Apple Silicon Macs"
    exit 1
fi

echo ""
print_info "This script will:"
echo "  1. Install Ollama (if not present)"
echo "  2. Configure power management for headless operation"
echo "  3. Create launchd service for Ollama"
echo "  4. Configure Ollama environment variables"
echo "  5. Set up auto-start on boot"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
fi

echo ""
echo "=================================================="
echo "Step 1: Ollama Installation"
echo "=================================================="
echo ""

OLLAMA_APP_PATH="/Applications/Ollama.app"
OLLAMA_BINARY="$OLLAMA_APP_PATH/Contents/Resources/ollama"

# Check if Ollama is already installed
if [ -d "$OLLAMA_APP_PATH" ] && [ -f "$OLLAMA_BINARY" ]; then
    print_status "Ollama already installed at $OLLAMA_APP_PATH"
    
    # Verify it's ARM64
    ARCH=$(file "$OLLAMA_BINARY" | grep -o "arm64\|x86_64")
    if [ "$ARCH" = "arm64" ]; then
        print_status "Ollama is native ARM64"
    else
        print_error "Existing Ollama is x86_64 (Rosetta)"
        read -p "Remove and reinstall ARM64 version? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing installation..."
            sudo rm -rf "$OLLAMA_APP_PATH"
            print_status "Removed"
        else
            print_error "Cannot proceed with x86_64 version"
            exit 1
        fi
    fi
fi

# Install Ollama if not present
if [ ! -d "$OLLAMA_APP_PATH" ]; then
    print_info "Ollama not found. Installing from ollama.com..."
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    print_info "Downloading Ollama installer..."
    
    # Download the latest Ollama installer
    # The official download URL redirects to the latest version
    if ! curl -L https://ollama.com/download/Ollama-darwin.zip -o Ollama.zip; then
        print_error "Failed to download Ollama"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    print_status "Download complete"
    
    print_info "Extracting installer..."
    if ! unzip -q Ollama.zip; then
        print_error "Failed to extract Ollama"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    print_status "Extraction complete"
    
    print_info "Installing Ollama to /Applications..."
    if [ -d "Ollama.app" ]; then
        # Move to Applications
        sudo mv Ollama.app /Applications/
        print_status "Ollama installed successfully"
    else
        print_error "Ollama.app not found in download"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # Clean up
    cd ~
    rm -rf "$TMP_DIR"
    print_status "Cleanup complete"
    
    # Verify installation
    if [ -f "$OLLAMA_BINARY" ]; then
        ARCH=$(file "$OLLAMA_BINARY" | grep -o "arm64\|x86_64")
        if [ "$ARCH" = "arm64" ]; then
            print_status "Verified: Ollama is native ARM64"
        else
            print_error "Downloaded version is not ARM64!"
            exit 1
        fi
    else
        print_error "Installation failed - binary not found"
        exit 1
    fi
else
    print_status "Using existing Ollama installation"
fi

# Kill any running Ollama instances
print_info "Stopping any running Ollama instances..."
pkill ollama 2>/dev/null || true
sleep 2
print_status "Ollama stopped"

echo ""
echo "=================================================="
echo "Step 2: Power Management Configuration"
echo "=================================================="
echo ""

print_info "Configuring pmset for headless operation..."

# Disable sleep entirely
sudo pmset -a sleep 0
print_status "Sleep disabled"

sudo pmset -a disablesleep 1
print_status "Sleep disable flag set"

# Disable disk sleep
sudo pmset -a disksleep 0
print_status "Disk sleep disabled"

# Disable standby
sudo pmset -a standby 0
print_status "Standby mode disabled"

# Disable autopoweroff
sudo pmset -a autopoweroff 0
print_status "Auto power off disabled"

# Disable powernap
sudo pmset -a powernap 0
print_status "Power nap disabled"

# Disable autorestart
sudo pmset -a autorestart 0
print_status "Auto restart on power failure disabled"

# Keep network alive
sudo pmset -a networkoversleep 0
print_status "Network over sleep disabled (not needed since sleep is off)"

# Wake on magic packet
sudo pmset -a womp 1
print_status "Wake on magic packet enabled"

# Display sleep (saves power, doesn't affect headless operation)
sudo pmset -a displaysleep 10
print_status "Display sleep set to 10 minutes"

# TCP keep alive
sudo pmset -a tcpkeepalive 1
print_status "TCP keep alive enabled"

echo ""
print_info "Current power settings:"
pmset -g

echo ""
read -p "Power settings look correct? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Please review settings and re-run script"
    exit 1
fi

echo ""
echo "=================================================="
echo "Step 3: Configure Ollama Environment"
echo "=================================================="
echo ""

# Get user input for configuration
read -p "Max loaded models [default: 3]: " MAX_MODELS
MAX_MODELS=${MAX_MODELS:-3}

read -p "Keep alive time in hours [default: 24]: " KEEP_ALIVE_HOURS
KEEP_ALIVE_HOURS=${KEEP_ALIVE_HOURS:-24}
KEEP_ALIVE_SECONDS=$((KEEP_ALIVE_HOURS * 3600))

read -p "Number of parallel requests [default: 4]: " NUM_PARALLEL
NUM_PARALLEL=${NUM_PARALLEL:-4}

read -p "Max context window [default: 32768]: " MAX_CONTEXT
MAX_CONTEXT=${MAX_CONTEXT:-32768}

read -p "Bind to all network interfaces? (y/n) [default: y]: " -n 1 -r BIND_ALL
echo
BIND_ALL=${BIND_ALL:-y}
if [[ $BIND_ALL =~ ^[Yy]$ ]]; then
    OLLAMA_HOST="0.0.0.0:11434"
else
    OLLAMA_HOST="127.0.0.1:11434"
fi

echo ""
print_info "Configuration:"
echo "  Max loaded models: $MAX_MODELS"
echo "  Keep alive: $KEEP_ALIVE_HOURS hours ($KEEP_ALIVE_SECONDS seconds)"
echo "  Parallel requests: $NUM_PARALLEL"
echo "  Max context: $MAX_CONTEXT tokens"
echo "  Bind address: $OLLAMA_HOST"
echo ""

read -p "Confirm configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Configuration cancelled"
    exit 1
fi

echo ""
echo "=================================================="
echo "Step 4: Create Launchd Service"
echo "=================================================="
echo ""

PLIST_PATH="/Library/LaunchDaemons/com.ollama.server.plist"

print_info "Creating launchd plist at $PLIST_PATH..."

# Backup existing plist if it exists
if [ -f "$PLIST_PATH" ]; then
    print_warning "Existing plist found, backing up..."
    sudo cp "$PLIST_PATH" "$PLIST_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backup created"
fi

# Create the plist file
sudo tee "$PLIST_PATH" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.server</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$OLLAMA_BINARY</string>
        <string>serve</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/tmp/ollama.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.err</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_MAX_LOADED_MODELS</key>
        <string>$MAX_MODELS</string>
        <key>OLLAMA_KEEP_ALIVE</key>
        <string>$KEEP_ALIVE_SECONDS</string>
        <key>OLLAMA_NUM_PARALLEL</key>
        <string>$NUM_PARALLEL</string>
        <key>OLLAMA_MAX_CONTEXT</key>
        <string>$MAX_CONTEXT</string>
        <key>OLLAMA_FLASH_ATTENTION</key>
        <string>1</string>
        <key>OLLAMA_NUM_GPU</key>
        <string>1</string>
        <key>OLLAMA_HOST</key>
        <string>$OLLAMA_HOST</string>
    </dict>
    
    <key>WorkingDirectory</key>
    <string>/tmp</string>
</dict>
</plist>
EOF

print_status "Launchd plist created"

# Set proper permissions
sudo chown root:wheel "$PLIST_PATH"
sudo chmod 644 "$PLIST_PATH"
print_status "Permissions set"

echo ""
echo "=================================================="
echo "Step 5: Load and Start Service"
echo "=================================================="
echo ""

# Unload if already loaded
sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Load the service
print_info "Loading Ollama service..."
sudo launchctl load "$PLIST_PATH"
print_status "Service loaded"

# Start the service
print_info "Starting Ollama service..."
sudo launchctl start com.ollama.server
sleep 3
print_status "Service started"

echo ""
echo "=================================================="
echo "Step 6: Verification"
echo "=================================================="
echo ""

# Check if process is running
if pgrep -x ollama > /dev/null; then
    print_status "Ollama process is running"
    
    # Get process info
    OLLAMA_PID=$(pgrep -x ollama)
    print_info "Process ID: $OLLAMA_PID"
    
    # Check architecture of running process
    PROC_ARCH=$(lipo -archs /proc/$OLLAMA_PID/exe 2>/dev/null || echo "unknown")
    print_info "Process architecture: $PROC_ARCH"
else
    print_error "Ollama process not running!"
    print_info "Check logs:"
    echo "  tail -f /tmp/ollama.log"
    echo "  tail -f /tmp/ollama.err"
    exit 1
fi

# Test API endpoint
print_info "Testing API endpoint..."
sleep 2

if curl -s http://localhost:11434/api/tags > /dev/null; then
    print_status "API endpoint responding"
else
    print_warning "API endpoint not responding yet (may still be starting)"
fi

# Display service status
echo ""
print_info "Service status:"
sudo launchctl list | grep ollama || print_warning "Service not found in launchctl list"

echo ""
echo "=================================================="
echo "Setup Summary"
echo "=================================================="
echo ""
print_status "Ollama installed and verified (ARM64)"
print_status "Power management configured for headless operation"
print_status "Ollama service created and started"
print_status "Service will auto-start on boot"
echo ""
print_info "Configuration:"
echo "  Ollama version: $(${OLLAMA_BINARY} --version 2>/dev/null || echo 'unknown')"
echo "  Max loaded models: $MAX_MODELS"
echo "  Keep alive: $KEEP_ALIVE_HOURS hours"
echo "  Parallel requests: $NUM_PARALLEL"
echo "  Max context: $MAX_CONTEXT tokens"
echo "  Bind address: $OLLAMA_HOST"
echo ""
print_info "Logs:"
echo "  Output: /tmp/ollama.log"
echo "  Errors: /tmp/ollama.err"
echo ""
print_info "Useful commands:"
echo "  Check status: sudo launchctl list | grep ollama"
echo "  Stop service: sudo launchctl stop com.ollama.server"
echo "  Restart service: sudo launchctl stop com.ollama.server && sudo launchctl start com.ollama.server"
echo "  View logs: tail -f /tmp/ollama.log"
echo "  Test API: curl http://localhost:11434/api/tags"
echo "  Pull a model: ${OLLAMA_BINARY} pull qwen2.5-coder:32b"
echo "  List models: ${OLLAMA_BINARY} list"
echo ""
print_info "Next steps:"
echo "  1. Test reboot to verify auto-start"
echo "  2. Pull your first model: ${OLLAMA_BINARY} pull qwen2.5-coder:7b"
echo "  3. Test inference: ${OLLAMA_BINARY} run qwen2.5-coder:7b"
echo ""
print_info "Testing reboot persistence..."
read -p "Reboot now to verify auto-start? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    print_warning "Remember to test reboot manually later!"
    echo ""
    print_status "Setup complete!"
fi
