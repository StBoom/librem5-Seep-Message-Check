#!/bin/bash

# Uninstaller for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
TIMESTAMP_DIR="/var/lib/wakeup-check"
SERVICE_PRE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SERVICE_POST_PATH="/etc/systemd/system/wakeup-check-post.service"
CONFIG_PATH="/etc/wakeup-check.conf"

echo "Stopping and disabling systemd services..."

systemctl disable --now wakeup-check-pre.service 2>/dev/null
systemctl disable --now wakeup-check-post.service 2>/dev/null

# Remove systemd service files
if [ -f "$SERVICE_PRE_PATH" ]; then
    echo "Removing $SERVICE_PRE_PATH..."
    rm "$SERVICE_PRE_PATH"
else
    echo "$SERVICE_PRE_PATH not found."
fi

if [ -f "$SERVICE_POST_PATH" ]; then
    echo "Removing $SERVICE_POST_PATH..."
    rm "$SERVICE_POST_PATH"
else
    echo "$SERVICE_POST_PATH not found."
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

# Remove script
if [ -f "$SCRIPT_PATH" ]; then
    echo "Removing $SCRIPT_PATH..."
    rm "$SCRIPT_PATH"
else
    echo "$SCRIPT_PATH not found."
fi

# Remove log file
if [ -f "$LOG_FILE" ]; then
    echo "Removing $LOG_FILE..."
    rm "$LOG_FILE"
else
    echo "$LOG_FILE not found."
fi

# Remove wake timestamp file and directory
if [ -f "$WAKE_TIMESTAMP_FILE" ]; then
    echo "Removing $WAKE_TIMESTAMP_FILE..."
    rm "$WAKE_TIMESTAMP_FILE"
else
    echo "$WAKE_TIMESTAMP_FILE not found."
fi

if [ -d "$TIMESTAMP_DIR" ]; then
    echo "Removing $TIMESTAMP_DIR if empty..."
    rmdir "$TIMESTAMP_DIR" 2>/dev/null || echo "Directory not empty, not removed."
fi

# Remove config file with prompt
if [ -f "$CONFIG_PATH" ]; then
    read -p "Do you also want to remove the config file at $CONFIG_PATH? (y/N): " delete_config
    if [[ "$delete_config" =~ ^[Yy]$ ]]; then
        rm "$CONFIG_PATH"
        echo "Config file removed."
    else
        echo "Config file kept."
    fi
else
    echo "Config file not found."
fi

echo "Uninstallation complete."
