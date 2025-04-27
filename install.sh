#!/bin/bash

# ---- Define Paths ----
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"

LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"

PRE_SERVICE_NAME="wakeup-check-pre.service"
PRE_SERVICE_SOURCE="./$PRE_SERVICE_NAME"
PRE_SERVICE_PATH="/etc/systemd/system/$PRE_SERVICE_NAME"

POST_SERVICE_NAME="wakeup-check-post.service"
POST_SERVICE_SOURCE="./$POST_SERVICE_NAME"
POST_SERVICE_PATH="/etc/systemd/system/$POST_SERVICE_NAME"

CONFIG_SOURCE="./wakeup-check.conf"
CONFIG_PATH="/etc/wakeup-check.conf"

# ---- Helper Function: Check Root Privileges ----
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo!"
    exit 1
fi

# ---- Copy Script ----
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Copying $SCRIPT_NAME to $SCRIPT_PATH..."
    cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
else
    echo "$SCRIPT_PATH already exists."
    read -p "Do you want to overwrite the script? (y/N): " overwrite_script
    if [[ "$overwrite_script" =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
        echo "Script has been overwritten at $SCRIPT_PATH."
    else
        echo "Keeping the existing script."
    fi
fi

# ---- Set Permissions for the Script ----
if [ -f "$SCRIPT_PATH" ]; then
    chmod 755 "$SCRIPT_PATH"
    chown root:root "$SCRIPT_PATH"
else
    echo "Error: Script not found at $SCRIPT_PATH. Aborting."
    exit 1
fi

# ---- Prepare Directories and Files ----
echo "Creating necessary directories and files..."

mkdir -p /var/lib/wakeup-check
chmod 755 /var/lib/wakeup-check

[ -f "$LOG_FILE" ] || { touch "$LOG_FILE"; chmod 644 "$LOG_FILE"; }

[ -f "$WAKE_TIMESTAMP_FILE" ] || { touch "$WAKE_TIMESTAMP_FILE"; chmod 644 "$WAKE_TIMESTAMP_FILE"; }
[ -f "$BRIGHTNESS_STORE_FILE" ] || { touch "$BRIGHTNESS_STORE_FILE"; chmod 644 "$BRIGHTNESS_STORE_FILE"; }

# ---- Install Configuration File ----
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH already exists."
    read -p "Do you want to overwrite the configuration file? (y/N): " overwrite_conf
    if [[ "$overwrite_conf" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_SOURCE" "$CONFIG_PATH"
        chmod 644 "$CONFIG_PATH"
        echo "Configuration file has been overwritten."
    else
        echo "Keeping the existing configuration file."
    fi
else
    echo "Installing configuration file to $CONFIG_PATH..."
    cp "$CONFIG_SOURCE" "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
    echo "Configuration file has been installed."
fi

# ---- Install Pre-Suspend systemd Service ----
echo "Installing systemd Pre-Suspend Service..."

if [ ! -f "$PRE_SERVICE_PATH" ]; then
    cp "$PRE_SERVICE_SOURCE" "$PRE_SERVICE_PATH"
    echo "Pre-Suspend Service installed at $PRE_SERVICE_PATH."
else
    echo "$PRE_SERVICE_PATH already exists."
    read -p "Do you want to overwrite the Pre-Suspend Service? (y/N): " overwrite_pre
    if [[ "$overwrite_pre" =~ ^[Yy]$ ]]; then
        cp "$PRE_SERVICE_SOURCE" "$PRE_SERVICE_PATH"
        echo "Pre-Suspend Service has been overwritten."
    else
        echo "Keeping the existing Pre-Suspend Service."
    fi
fi

# ---- Install Post-Suspend systemd Service ----
echo "Installing systemd Post-Suspend Service..."

if [ ! -f "$POST_SERVICE_PATH" ]; then
    cp "$POST_SERVICE_SOURCE" "$POST_SERVICE_PATH"
    echo "Post-Suspend Service installed at $POST_SERVICE_PATH."
else
    echo "$POST_SERVICE_PATH already exists."
    read -p "Do you want to overwrite the Post-Suspend Service? (y/N): " overwrite_post
    if [[ "$overwrite_post" =~ ^[Yy]$ ]]; then
        cp "$POST_SERVICE_SOURCE" "$POST_SERVICE_PATH"
        echo "Post-Suspend Service has been overwritten."
    else
        echo "Keeping the existing Post-Suspend Service."
    fi
fi

# ---- Reload systemd and Enable Services ----
echo "Reloading systemd and enabling Pre-Suspend Service..."
systemctl daemon-reload
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service

echo "Installation complete."
