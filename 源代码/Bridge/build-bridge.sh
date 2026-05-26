#!/bin/bash
# Build the agent-halo-bridge binary for the current architecture
# This binary is deployed to ~/.agent-halo/bin/ by the app on first launch

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/agent-halo-bridge.swift"
OUTPUT="$SCRIPT_DIR/agent-halo-bridge"

echo "Building agent-halo-bridge..."
swiftc -O -o "$OUTPUT" "$SOURCE" 2>&1

if [ $? -eq 0 ]; then
    chmod +x "$OUTPUT"
    echo "Built successfully: $OUTPUT"
    RESOURCES_DIR="$SCRIPT_DIR/../AINotchIsland/Resources"
    cp "$OUTPUT" "$RESOURCES_DIR/agent-halo-bridge"
    echo "Copied to: $RESOURCES_DIR/agent-halo-bridge"
else
    echo "Build failed!"
    exit 1
fi
