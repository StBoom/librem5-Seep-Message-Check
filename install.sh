#!/bin/bash

# Installer for Wakeup Check Service

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-timestamp"

# Ensure the script has the correct permissions
echo "Setting executable permissions for $SCRIPT_PATH..."
chmod +x $SCRIPT_PATH

# Copy the wakeup-check.sh script to /usr/local/bin
echo "Copying wakeup-check.sh to $SCRIPT_PATH..."
cp wakeup-check.sh $SCRIPT_PATH

# Create necessary directories and files if they do not exist
echo "Creating necessary directories and files..."

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

# Set the correct permissions for the script and the config
chmod 755 $SCRIPT_PATH
chmod 644 $LOG_FILE
chmod 644 $WAKE_TIMESTAMP_FILE

# Install systemd service files
echo "Installing systemd service files..."

# Copy the pre-suspend service
cp wakeup-check-pre.service /etc/systemd/system/

# Copy the post-suspend service
cp wakeup-check-post.service /etc/systemd/system/

# Set permissions for the systemd service files
chmod 644 /etc/systemd/system/wakeup-check-pre.service
chmod 644 /etc/systemd/system/wakeup-check-post.service

# Reload systemd to register the new services
echo "Reloading systemd..."
systemctl daemon-reload

# Enable services to start on boot
echo "Enabling systemd services..."
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service

# Print the completion message
echo "Installation complete. The services have been installed and enabled."
