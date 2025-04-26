#!/bin/bash

# Define paths
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
CONFIG_SOURCE="./wakeup-check.conf"
CONFIG_PATH="/etc/wakeup-check.conf"

# Service paths
PRE_SERVICE_PATH="/etc/systemd/system/wakeup-check-pre.service"
POST_SERVICE_PATH="/etc/systemd/system/wakeup-check-post.service"

# Kopieren des Skripts nach /usr/local/bin, nur wenn es nicht existiert
# ...

# Installiere systemd Pre-Suspend Service
echo "Installiere systemd Pre-Suspend Service..."
cat > "$PRE_SERVICE_PATH" << EOF
[Unit]
Description=Wakeup Check Pre Suspend
Before=suspend.target
Conflicts=wakeup-check-post.service
After=wakeup-check-post.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wakeup-check.sh pre
TimeoutStartSec=300

[Install]
WantedBy=suspend.target
EOF
chmod 644 "$PRE_SERVICE_PATH"
systemctl daemon-reload
systemctl enable wakeup-check-pre.service

# Installiere systemd Post-Resume Service
echo "Installiere systemd Post-Resume Service..."
cat > "$POST_SERVICE_PATH" << EOF
[Unit]
Description=Wakeup Check Post Resume
After=suspend.target
Conflicts=wakeup-check-pre.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wakeup-check.sh post
TimeoutStartSec=300

[Install]
WantedBy=suspend.target
EOF
chmod 644 "$POST_SERVICE_PATH"
systemctl daemon-reload
systemctl enable wakeup-check-post.service
