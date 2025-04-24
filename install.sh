#!/bin/bash

# Installer for Wakeup Check Service

# Define paths
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
SERVICE_PRE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SERVICE_POST_PATH="/etc/systemd/system/wakeup-check-post.service"
CONFIG_SOURCE="./wakeup-check.conf"
CONFIG_PATH="/etc/wakeup-check.conf"

# Copy the wakeup-check.sh script to /usr/local/bin, only if it doesn't exist
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Copying $SCRIPT_NAME to $SCRIPT_PATH..."
    cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
else
    echo "$SCRIPT_PATH already exists."
    read -p "Do you want to overwrite the script? (y/N): " overwrite_script
    if [[ "$overwrite_script" =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
        echo "Script overwritten at $SCRIPT_PATH."
    else
        echo "Keeping existing script."
    fi
fi

# Set the correct permissions for the script
if [ -f "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
else
    echo "Error: Script not found at $SCRIPT_PATH. Aborting."
    exit 1
fi

# Create necessary directories and files if they do not exist
echo "Creating necessary directories and files..."

# Directory for timestamp
if [ ! -d "/var/lib/wakeup-check" ]; then
    echo "Creating /var/lib/wakeup-check..."
    mkdir -p /var/lib/wakeup-check
    chmod 755 /var/lib/wakeup-check
else
    echo "Directory /var/lib/wakeup-check already exists."
fi

# Log file
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    echo "Log file created at $LOG_FILE."
else
    echo "Log file already exists."
fi

# Timestamp file
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch "$WAKE_TIMESTAMP_FILE"
    chmod 644 "$WAKE_TIMESTAMP_FILE"
    echo "Timestamp file created at $WAKE_TIMESTAMP_FILE."
else
    echo "Timestamp file already exists."
fi

# Brightness file (to store previous brightness before display off)
if [ ! -f "$BRIGHTNESS_STORE_FILE" ]; then
    touch $BRIGHTNESS_STORE_FILE
    chmod 644 $BRIGHTNESS_STORE_FILE
    echo "Brightness store file created at $BRIGHTNESS_STORE_FILE with 644 permissions."
else
    echo "Brightness store file already exists."
fi

# Install config file
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH already exists."
    read -p "Do you want to overwrite the config file? (y/N): " overwrite_conf
    if [[ "$overwrite_conf" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_SOURCE" "$CONFIG_PATH"
        chmod 644 "$CONFIG_PATH"
        echo "Config file overwritten at $CONFIG_PATH."
    else
        echo "Keeping existing config file."
    fi
else
    echo "Installing config file to $CONFIG_PATH..."
    cp "$CONFIG_SOURCE" "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
    echo "Config file installed."
fi

# Install systemd service files
echo "Installing systemd service files..."

if [ ! -f "$SERVICE_PRE_PATH" ]; then
    cp wakeup-check-pre.service "$SERVICE_PRE_PATH"
    chmod 644 "$SERVICE_PRE_PATH"
    echo "Pre-suspend service file installed."
else
    echo "$SERVICE_PRE_PATH already exists. Skipping copy."
fi

if [ ! -f "$SERVICE_POST_PATH" ]; then
    cp wakeup-check-post.service "$SERVICE_POST_PATH"
    chmod 644 "$SERVICE_POST_PATH"
    echo "Post-suspend service file installed."
else
    echo "$SERVICE_POST_PATH already exists. Skipping copy."
fi

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable services
echo "Enabling services..."
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service

echo "Installation complete."
