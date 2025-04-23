#!/bin/bash

# Installer for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
SERVICE_PRE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SERVICE_POST_PATH="/etc/systemd/system/wakeup-check-post.service"
CONFIG_PATH="/etc/wakeup-check.conf"

# Ensure the script has the correct permissions
echo "Setting executable permissions for $SCRIPT_PATH..."
chmod +x $SCRIPT_PATH

# Copy the wakeup-check.sh script to /usr/local/bin, only if it doesn't exist
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Copying wakeup-check.sh to $SCRIPT_PATH..."
    cp wakeup-check.sh $SCRIPT_PATH
else
    echo "$SCRIPT_PATH already exists. Skipping copy."
fi

# Create necessary directories and files if they do not exist
echo "Creating necessary directories and files..."

# Ensure the directory for the timestamp file exists
if [ ! -d "/var/lib/wakeup-check" ]; then
    echo "Creating directory /var/lib/wakeup-check..."
    mkdir -p /var/lib/wakeup-check
    chmod 755 /var/lib/wakeup-check
else
    echo "Directory /var/lib/wakeup-check already exists."
fi

# Log file
if [ ! -f "$LOG_FILE" ]; then
    touch $LOG_FILE
    chmod 644 $LOG_FILE
    echo "Log file created at $LOG_FILE with 644 permissions."
else
    echo "Log file already exists."
fi

# Wake timestamp file
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch $WAKE_TIMESTAMP_FILE
    chmod 644 $WAKE_TIMESTAMP_FILE
    echo "Timestamp file created at $WAKE_TIMESTAMP_FILE with 644 permissions."
else
    echo "Timestamp file already exists."
fi

# Config file
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH already exists."
    read -p "Do you want to overwrite the existing config file? (y/N): " overwrite
    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
        cp wakeup-check.conf $CONFIG_PATH
        chmod 644 $CONFIG_PATH
        echo "Config file overwritten at $CONFIG_PATH."
    else
        echo "Keeping existing config file."
    fi
else
    echo "Copying wakeup-check.conf to $CONFIG_PATH..."
    cp wakeup-check.conf $CONFIG_PATH
    chmod 644 $CONFIG_PATH
    echo "Config file installed at $CONFIG_PATH with 644 permissions."
fi

# Set the correct permissions
chmod 755 $SCRIPT_PATH
chmod 644 $LOG_FILE
chmod 644 $WAKE_TIMESTAMP_FILE

# Install systemd service files, only if they don't exist
echo "Installing systemd service files..."

if [ ! -f "$SERVICE_PRE_PATH" ]; then
    cp wakeup-check-pre.service $SERVICE_PRE_PATH
    chmod 644 $SERVICE_PRE_PATH
    echo "Pre-suspend service file installed."
else
    echo "$SERVICE_PRE_PATH already exists. Skipping copy."
fi

if [ ! -f "$SERVICE_POST_PATH" ]; then
    cp wakeup-check-post.service $SERVICE_POST_PATH
    chmod 644 $SERVICE_POST_PATH
    echo "Post-suspend service file installed."
else
    echo "$SERVICE_POST_PATH already exists. Skipping copy."
fi

# Reload systemd to register the new services
echo "Reloading systemd..."
systemctl daemon-reload

# Enable services to start on suspend
echo "Enabling systemd services
EOF
