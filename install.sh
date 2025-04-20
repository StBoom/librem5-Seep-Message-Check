#!/bin/bash

# Installation directory
REPO_DIR="$(pwd)"

# Target directories
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
CONF_DIR="/etc"
WAKEUP_CHECK_SCRIPT="wakeup-check.sh"
SERVICE_FILE_PRE="wakeup-check-pre.service"
SERVICE_FILE_POST="wakeup-check-post.service"
CONF_FILE="wakeup-check.conf"
LOG_DIR="/var/log/wakeup-check"
WAKE_TIMESTAMP_FILE="$LOG_DIR/wake_timestamp"
LOG_FILE="$LOG_DIR/wakeup-check.log"

# Helper function: Log message
log() {
    echo "[INFO] $1"
}

# Check if script is being run as root
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root!" 
    exit 1
fi

# 1. Copy the main script to the target directory
log "Copying $WAKEUP_CHECK_SCRIPT to $BIN_DIR"
cp "$REPO_DIR/$WAKEUP_CHECK_SCRIPT" "$BIN_DIR/$WAKEUP_CHECK_SCRIPT"

# 2. Copy the systemd service files
log "Copying $SERVICE_FILE_PRE and $SERVICE_FILE_POST to $SERVICE_DIR"
cp "$REPO_DIR/$SERVICE_FILE_PRE" "$SERVICE_DIR/$SERVICE_FILE_PRE"
cp "$REPO_DIR/$SERVICE_FILE_POST" "$SERVICE_DIR/$SERVICE_FILE_POST"

# 3. Copy the configuration file
log "Copying $CONF_FILE to $CONF_DIR"
cp "$REPO_DIR/$CONF_FILE" "$CONF_DIR/$CONF_FILE"

# 4. Set executable permissions for the main script
log "Setting executable permissions for $WAKEUP_CHECK_SCRIPT"
chmod +x "$BIN_DIR/$WAKEUP_CHECK_SCRIPT"

# 5. Set appropriate permissions for the systemd service files
log "Setting appropriate permissions for the systemd service files"
chmod 644 "$SERVICE_DIR/$SERVICE_FILE_PRE"
chmod 644 "$SERVICE_DIR/$SERVICE_FILE_POST"

# 6. Create the log directory if it doesn't exist
log "Creating log directory if it doesn't exist"
mkdir -p "$LOG_DIR"

# 7. Create the log file if it doesn't exist
log "Creating log file if it doesn't exist"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log "Log file created: $LOG_FILE"
else
    log "Log file already exists."
fi

# 8. Set the correct permissions for the log file
log "Setting correct permissions for the log file"
chmod 640 "$LOG_FILE"  # Root (write) + Group (read)

# 9. Create the timestamp file if it doesn't exist
log "Creating the timestamp file if it doesn't exist"
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch "$WAKE_TIMESTAMP_FILE"
    log "Timestamp file created: $WAKE_TIMESTAMP_FILE"
else
    log "Timestamp file already exists."
fi

# 10. Set the correct permissions for the timestamp file
log "Setting correct permissions for the timestamp file"
chmod 640 "$WAKE_TIMESTAMP_FILE"  # Root (write) + Group (read)

# 11. Enable the systemd services
log "Enabling systemd services: $SERVICE_FILE_PRE and $SERVICE_FILE_POST"
systemctl enable "$SERVICE_DIR/$SERVICE_FILE_PRE"
systemctl enable "$SERVICE_DIR/$SERVICE_FILE_POST"

# 12. Start the systemd services
log "Starting systemd services: $SERVICE_FILE_PRE and $SERVICE_FILE_POST"
systemctl start wakeup-check-pre.service
systemctl start wakeup-check-post.service

# 13. Verify if the services are running
log "Checking the status of the systemd services"
systemctl status wakeup-check-pre.service
systemctl status wakeup-check-post.service

log "Installation completed!"
