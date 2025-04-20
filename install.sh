#!/bin/bash

# Installer for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_DIR="/var/lib/wakeup-check"
WAKE_TIMESTAMP_FILE="$WAKE_DIR/last_wake_timestamp"
CONFIG_FILE="/etc/wakeup-check.conf"

echo "=== Installing Wakeup Check Service ==="

# Create script target directory if needed
mkdir -p "$(dirname "$SCRIPT_PATH")"

# Copy the wakeup-check.sh script to /usr/local/bin
echo "Copying wakeup-check.sh to $SCRIPT_PATH..."
cp wakeup-check.sh "$SCRIPT_PATH"
chmod 755 "$SCRIPT_PATH"

# Copy config file
if [ -f "wakeup-check.conf" ]; then
    echo "Copying config to $CONFIG_FILE..."
    cp wakeup-check.conf "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
else
    echo "[WARNING] Config file 'wakeup-check.conf' not found – skipping."
fi

# Create necessary directories
mkdir -p "$WAKE_DIR"

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    echo "Log file created at $LOG_FILE with 644 permissions."
else
    echo "Log file already exists."
fi

# Create wake timestamp file if it doesn't exist
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch "$WAKE_TIMESTAMP_FILE"
    chmod 644 "$WAKE_TIMESTAMP_FILE"
    echo "Timestamp file created at $WAKE_TIMESTAMP_FILE with 644 permissions."
else
    echo "Timestamp file already exists."
fi

# Install systemd service files
echo "Installing systemd service files..."
cp wakeup-check-pre.service /etc/systemd/system/
cp wakeup-check-post.service /etc/systemd/system/
chmod 644 /etc/systemd/system/wakeup-check-pre.service
chmod 644 /etc/systemd/system/wakeup-check-post.service

# Reload systemd to register the new services
echo "Reloading systemd..."
systemctl daemon-reload

# Enable and start services
echo "Enabling and starting systemd services..."
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service
systemctl start wakeup-check-pre.service
systemctl start wakeup-check-post.service

echo "✅ Installation complete and services started."
