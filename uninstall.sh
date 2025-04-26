#!/bin/bash

# Define paths
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
SLEEP_HOOK_PATH="/lib/systemd/system-sleep/wakeup-check"
CONFIG_PATH="/etc/wakeup-check.conf"
WAKEUP_DIR="/var/lib/wakeup-check"

# Entfernen des Skripts
if [ -f "$SCRIPT_PATH" ]; then
    echo "Entferne $SCRIPT_PATH..."
    rm "$SCRIPT_PATH"
else
    echo "Skript wurde nicht unter $SCRIPT_PATH gefunden."
fi

# Entfernen der Log-Datei
if [ -f "$LOG_FILE" ]; then
    echo "Entferne $LOG_FILE..."
    rm "$LOG_FILE"
else
    echo "Log-Datei wurde nicht unter $LOG_FILE gefunden."
fi

# Entfernen der Timestamp-Datei
if [ -f "$WAKE_TIMESTAMP_FILE" ]; then
    echo "Entferne $WAKE_TIMESTAMP_FILE..."
    rm "$WAKE_TIMESTAMP_FILE"
else
    echo "Timestamp-Datei wurde nicht unter $WAKE_TIMESTAMP_FILE gefunden."
fi

# Entfernen der Helligkeits-Datei
if [ -f "$BRIGHTNESS_STORE_FILE" ]; then
    echo "Entferne $BRIGHTNESS_STORE_FILE..."
    rm -f "$BRIGHTNESS_STORE_FILE"
else
    echo "$BRIGHTNESS_STORE_FILE wurde nicht gefunden. Nichts zu entfernen."
fi

# Entfernen der Konfigurationsdatei
if [ -f "$CONFIG_PATH" ]; then
    echo "Entferne $CONFIG_PATH..."
    rm "$CONFIG_PATH"
else
    echo "Konfigurationsdatei wurde nicht unter $CONFIG_PATH gefunden."
fi

# Entfernen des systemd sleep hook-Skripts
if [ -f "$SLEEP_HOOK_PATH" ]; then
    echo "Entferne Sleep Hook-Skript unter $SLEEP_HOOK_PATH..."
    rm "$SLEEP_HOOK_PATH"
else
    echo "Sleep Hook-Skript wurde nicht unter $SLEEP_HOOK_PATH gefunden."
fi

# Überprüfen und Entfernen des wakeup-check Verzeichnisses, wenn es leer ist
if [ -d "$WAKEUP_DIR" ] && [ -z "$(ls -A $WAKEUP_DIR)" ]; then
    echo "Entferne leeres Verzeichnis $WAKEUP_DIR..."
    rmdir "$WAKEUP_DIR"
else
    echo "Verzeichnis $WAKEUP_DIR ist nicht leer oder existiert nicht."
fi

echo "Deinstallation abgeschlossen."
