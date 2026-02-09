#!/bin/bash
set -e

echo "=== mac-screen-reader installer ==="
echo ""

# Build
echo "Building with Swift (release mode)..."
swift build -c release

# Install directory
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="MacScreenReader"
SOURCE=".build/release/$BINARY_NAME"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Build succeeded but binary not found at $SOURCE"
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$SOURCE" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Installed to $INSTALL_DIR/$BINARY_NAME"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "WARNING: $INSTALL_DIR is not in your PATH."
    echo "Add the following to your shell profile (~/.zshrc or ~/.bashrc):"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo ""
echo "=== Setup ==="
echo ""
echo "To add to Claude Code, run:"
echo ""
echo "  claude mcp add mac-screen-reader $INSTALL_DIR/$BINARY_NAME"
echo ""
echo "Make sure Screen Recording permission is granted to your terminal app."
echo "(System Settings > Privacy & Security > Screen Recording)"
echo ""
echo "Done!"
