#!/bin/bash

# Claude MCP Manager + Dev Tools Installation Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/mcp-management"
BIN_DIR="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"

echo "Installing Claude MCP Manager + Dev Tools..."
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install it first:"
    echo "  sudo apt-get update && sudo apt-get install -y jq"
    exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Copy MCP manager files (skip if running from install dir to avoid copying onto itself)
echo "Installing MCP manager..."
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    cp "$SCRIPT_DIR/mcp-manager.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/servers-library.json" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/.example.env" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/commands.md" "$INSTALL_DIR/"
else
    echo "  Running from install dir, skipping file copy"
fi
chmod +x "$INSTALL_DIR/mcp-manager.sh"

# Create .env file if it doesn't exist
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "Creating .env file from template..."
    cp "$INSTALL_DIR/.example.env" "$INSTALL_DIR/.env"
    echo "NOTE: Please edit $INSTALL_DIR/.env and add your API keys"
fi

# Install utility scripts to ~/.local/bin
echo "Installing utility scripts..."
for script in "$SCRIPT_DIR/bin/"*; do
    if [ -f "$script" ]; then
        name=$(basename "$script")
        cp "$script" "$BIN_DIR/$name"
        chmod +x "$BIN_DIR/$name"
        echo "  Installed: $name"
    fi
done

# Install bash aliases
echo "Installing bash aliases..."
cp "$SCRIPT_DIR/bash_aliases" "$HOME/.bash_aliases"
echo "  Installed: ~/.bash_aliases"

# Check if bashrc already has the configuration
if grep -q "mcp-management" "$BASHRC" 2>/dev/null; then
    echo ""
    echo "WARNING: Found existing mcp-management configuration in $BASHRC"
    echo "Skipping bashrc modification (already configured)."
else
    echo ""
    echo "Adding configuration to $BASHRC..."
    cat >> "$BASHRC" << 'EOF'

# Claude MCP Manager + Dev Tools
export PATH="$HOME/.local/bin:$HOME/mcp-management:$PATH"
alias mcp-manager="$HOME/mcp-management/mcp-manager.sh"
[ -f "$HOME/.bash_aliases" ] && . "$HOME/.bash_aliases"
EOF
fi

echo ""
echo "Installation complete!"
echo ""
echo "Installed:"
echo "  - mcp-manager  (MCP server management)"
echo "  - get-started   (project clone + secrets restore)"
echo "  - wrap-up       (commit, push, PR, backup, cleanup)"
echo "  - spark         (SSH to DGX Spark)"
echo "  - rterm         (kitty terminal theming)"
echo "  - yolo          (claude --dangerously-skip-permissions)"
echo "  - bash aliases  (git shortcuts, safety, cloudflare)"
echo ""
echo "Next steps:"
echo "  1. Edit $INSTALL_DIR/.env and add your API keys"
echo "  2. Reload your shell: source ~/.bashrc"
echo "  3. Try it out: mcp-manager list"
echo ""
