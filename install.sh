#!/bin/bash

# ---- Define Paths ----
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"

LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"

PRE_SERVICE_NAME="wakeup-check-pre.service"
PRE_SERVICE_PATH="/etc/systemd/system/$PRE_SERVICE_NAME"

POST_SERVICE_NAME="wakeup-check-post.service"
POST_SERVICE_PATH="/etc/systemd/system/$POST_SERVICE_NAME"

CONFIG_PATH="/etc/wakeup-check.conf"

# ---- Helper Function: Check Root Privileges ----
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo!"
    exit 1
fi

# ---- Remove Pre-Suspend Service ----
echo "Removing Pre-Suspend systemd Service..."
if [ -f "$PRE_SERVICE_PATH" ]; then
    rm "$PRE_SERVICE_PATH"
    echo "Pre-Suspend Service removed."
else
    echo "Pre-Suspend Service not found at $PRE_SERVICE_PATH."
fi

# ---- Remove Post-Suspend Service ----
echo "Removing Post-Suspend systemd Service..."
if [ -f "$POST_SERVICE_PATH" ]; then
    rm "$POST_SERVICE_PATH"
    echo "Post-Suspend Service removed."
else
    echo "Post-Suspend Service not found at $POST_SERVICE_PATH."
fi

# ---- Remove Script ----
echo "Removing script $SCRIPT_PATH..."
if [ -f "$SCRIPT_PATH" ]; then
    rm "$SCRIPT_PATH"
    echo "Script removed."
else
    echo "Script not found at $SCRIPT_PATH."
fi

# ---- Remove Configuration File ----
echo "Removing configuration file $CONFIG_PATH..."
if [ -f "$CONFIG_PATH" ]; then
    rm "$CONFIG_PATH"
    echo "Configuration file removed."
else
    echo "Configuration file not found at $CONFIG_PATH."
fi

# ---- Remove Log Files ----
echo "Removing log file $LOG_FILE..."
if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    echo "Log file removed."
else
    echo "Log file not found at $LOG_FILE."
fi

# ---- Remove Other Files ----
echo "Removing other related files..."
if [ -f "$WAKE_TIMESTAMP_FILE" ]; then
    rm "$WAKE_TIMESTAMP_FILE"
    echo "Wake timestamp file removed."
else
    echo "Wake timestamp file not found at $WAKE_TIMESTAMP_FILE."
fi

if [ -f "$BRIGHTNESS_STORE_FILE" ]; then
    rm "$BRIGHTNESS_STORE_FILE"
    echo "Brightness store file removed."
else
    echo "Brightness store file not found at $BRIGHTNESS_STORE_FILE."
fi

# ---- Reload systemd Daemon and Disable Services ----
echo "Reloading systemd and disabling services..."
systemctl daemon-reload
systemctl disable wakeup-check-pre.service
systemctl disable wakeup-check-post.service

# ---- Final Message ----
echo "Uninstallation complete."
