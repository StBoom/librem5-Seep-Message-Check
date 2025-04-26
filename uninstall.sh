#!/bin/bash

# ---- Pfade definieren ----
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
LIB_DIR="/var/lib/wakeup-check"
CONFIG_PATH="/etc/wakeup-check.conf"
PRE_SERVICE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SYSTEM_SLEEP_HOOK="/lib/systemd/system-sleep/wakeup-check-post.sh"

# ---- Root-Rechte prüfen ----
if [ "$EUID" -ne 0 ]; then
    echo "Bitte als root oder mit sudo ausführen!"
    exit 1
fi

echo "Starte Deinstallation von wakeup-check..."

# ---- systemd Service stoppen und deaktivieren ----
if systemctl is-enabled --quiet wakeup-check-pre.service; then
    echo "Deaktiviere und stoppe wakeup-check-pre.service..."
    systemctl disable --now wakeup-check-pre.service
fi

# ---- systemd Service Datei löschen ----
if [ -f "$PRE_SERVICE_PATH" ]; then
    echo "Lösche systemd Service Datei $PRE_SERVICE_PATH..."
    rm -f "$PRE_SERVICE_PATH"
fi

# ---- system-sleep Hook löschen ----
if [ -f "$SYSTEM_SLEEP_HOOK" ]; then
    echo "Lösche system-sleep Hook $SYSTEM_SLEEP_HOOK..."
    rm -f "$SYSTEM_SLEEP_HOOK"
fi

# ---- Skript löschen ----
if [ -f "$SCRIPT_PATH" ]; then
    echo "Lösche Hauptskript $SCRIPT_PATH..."
    rm -f "$SCRIPT_PATH"
fi

# ---- Konfigurationsdatei löschen ----
if [ -f "$CONFIG_PATH" ]; then
    echo "Lösche Konfigurationsdatei $CONFIG_PATH..."
    rm -f "$CONFIG_PATH"
fi

# ---- Log-Datei löschen ----
if [ -f "$LOG_FILE" ]; then
    echo "Lösche Log-Datei $LOG_FILE..."
    rm -f "$LOG_FILE"
fi

# ---- Timestamps und Helligkeitsdatei löschen ----
if [ -f "$WAKE_TIMESTAMP_FILE" ]; then
    echo "Lösche Timestamp-Datei $WAKE_TIMESTAMP_FILE..."
    rm -f "$WAKE_TIMESTAMP_FILE"
fi

if [ -f "$BRIGHTNESS_STORE_FILE" ]; then
    echo "Lösche Helligkeitsdatei $BRIGHTNESS_STORE_FILE..."
    rm -f "$BRIGHTNESS_STORE_FILE"
fi

# ---- Verzeichnis /var/lib/wakeup-check löschen (nur wenn leer) ----
if [ -d "$LIB_DIR" ]; then
    if [ "$(ls -A "$LIB_DIR")" ]; then
        echo "Verzeichnis $LIB_DIR ist nicht leer. Dateien wurden gelöscht."
    else
        echo "Lösche leeres Verzeichnis $LIB_DIR..."
        rmdir "$LIB_DIR"
    fi
fi

# ---- systemd Daemon neu laden ----
echo "Aktualisiere systemd..."
systemctl daemon-reload

echo "Deinstallation abgeschlossen."
