#!/bin/bash

# Uninstaller for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_DIR="/var/lib/wakeup-check"
WAKE_TIMESTAMP_FILE="$WAKE_DIR/last_wake_timestamp"
CONFIG_FILE="/etc/wakeup-check.conf"

echo "=== Uninstalling Wakeup Check Service ==="

# Stop systemd services
echo "Stopping systemd services..."
systemctl stop wakeup-check-pre.service
systemctl stop wakeup-check-post.service

# Disable services
echo "Disabling systemd services..."
systemctl disable wakeup-check-pre.service
systemctl disable wakeup-check-post.service

# Remove systemd service files
echo "Removing systemd unit files..."
rm -f /etc/systemd/system/wakeup-check-pre.service
rm -f /etc/systemd/system/wakeup-check-post.service

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Remove main script
if [ -f "$SCRIPT_PATH" ]; then
    echo "Removing script at $SCRIPT_PATH..."
    rm -f "$SCRIPT_PATH"
fi

# Prompt before removing config and data
read -p "Do you want to remove the config file at $CONFIG_FILE? [y/N]: " remove_config
if [[ "$remove_config" =~ ^[Yy]$ ]]; then
    rm -f "$CONFIG_FILE"
    echo "Config file removed."
fi

read -p "Do you want to remove the log file at $LOG_FILE? [y/N]: " remove_log
if [[ "$remove_log" =~ ^[Yy]$ ]]; then
    rm -f "$LOG_FILE"
    echo "Log file removed."
fi

read -p "Do you want to remove the timestamp file at $WAKE_TIMESTAMP_FILE? [y/N]: " remove_ts
if [[ "$remove_ts" =~ ^[Yy]$ ]]; then
    rm -f "$WAKE_TIMESTAMP_FILE"
    echo "Timestamp file removed."
    # Remove directory if empty
    rmdir "$WAKE_DIR" 2>/dev/null && echo "Removed empty directory $WAKE_DIR."
fi

echo "Uninstallation complete."
