#!/bin/bash

# Uninstaller for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
SERVICE_PRE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SERVICE_POST_PATH="/etc/systemd/system/wakeup-check-post.service"
CONFIG_PATH="/etc/wakeup-check.conf"
WAKEUP_DIR="/var/lib/wakeup-check"

# Remove the script
if [ -f "$SCRIPT_PATH" ]; then
    echo "Removing $SCRIPT_PATH..."
    rm "$SCRIPT_PATH"
else
    echo "Script not found at $SCRIPT_PATH."
fi

# Remove log file
if [ -f "$LOG_FILE" ]; then
    echo "Removing $LOG_FILE..."
    rm "$LOG_FILE"
else
    echo "Log file not found at $LOG_FILE."
fi

# Remove timestamp file
if [ -f "$WAKE_TIMESTAMP_FILE" ]; then
    echo "Removing $WAKE_TIMESTAMP_FILE..."
    rm "$WAKE_TIMESTAMP_FILE"
else
    echo "Timestamp file not found at $WAKE_TIMESTAMP_FILE."
fi

# Remove config file
if [ -f "$CONFIG_PATH" ]; then
    echo "Removing $CONFIG_PATH..."
    rm "$CONFIG_PATH"
else
    echo "Config file not found at $CONFIG_PATH."
fi

# Remove systemd service files
if [ -f "$SERVICE_PRE_PATH" ]; then
    echo "Removing $SERVICE_PRE_PATH..."
    rm "$SERVICE_PRE_PATH"
else
    echo "Pre-suspend service file not found."
fi

if [ -f "$SERVICE_POST_PATH" ]; then
    echo "Removing $SERVICE_POST_PATH..."
    rm "$SERVICE_POST_PATH"
else
    echo "Post-suspend service file not found."
fi

# Disable and stop systemd services if they exist
echo "Disabling systemd services..."
systemctl is-enabled --quiet wakeup-check-pre.service && systemctl disable wakeup-check-pre.service
systemctl is-enabled --quiet wakeup-check-post.service && systemctl disable wakeup-check-post.service

# Reload systemd to clear out the services
echo "Reloading systemd..."
systemctl daemon-reload

# Check if the wakeup-check directory is empty and remove it
if [ -d "$WAKEUP_DIR" ] && [ -z "$(ls -A $WAKEUP_DIR)" ]; then
    echo "Removing empty directory $WAKEUP_DIR..."
    rmdir "$WAKEUP_DIR"
else
    echo "Directory $WAKEUP_DIR is not empty or does not exist."
fi

echo "Uninstallation complete."
