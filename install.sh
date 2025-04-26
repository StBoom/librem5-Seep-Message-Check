#!/bin/bash

# Define paths
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
PRE_SERVICE_NAME="wakeup-check-pre.service"
POST_SERVICE_NAME="wakeup-check-post.service"
PRE_SERVICE_SOURCE="./$PRE_SERVICE_NAME"
POST_SERVICE_SOURCE="./$POST_SERVICE_NAME"
PRE_SERVICE_PATH="/etc/systemd/system/$PRE_SERVICE_NAME"
POST_SERVICE_PATH="/etc/systemd/system/$POST_SERVICE_NAME"
CONFIG_SOURCE="./wakeup-check.conf"
CONFIG_PATH="/etc/wakeup-check.conf"

# Kopieren des Skripts nach /usr/local/bin, nur wenn es nicht existiert
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Kopiere $SCRIPT_NAME nach $SCRIPT_PATH..."
    cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
else
    echo "$SCRIPT_PATH existiert bereits."
    read -p "Möchten Sie das Skript überschreiben? (y/N): " overwrite_script
    if [[ "$overwrite_script" =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
        echo "Skript wurde unter $SCRIPT_PATH überschrieben."
    else
        echo "Behalte das bestehende Skript."
    fi
fi

# Setzen der richtigen Berechtigungen für das Skript
if [ -f "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
else
    echo "Fehler: Skript nicht gefunden unter $SCRIPT_PATH. Abbruch."
    exit 1
fi

# Erstellen notwendiger Verzeichnisse und Dateien, falls sie nicht existieren
echo "Erstelle notwendige Verzeichnisse und Dateien..."

# Verzeichnis für Timestamps
if [ ! -d "/var/lib/wakeup-check" ]; then
    echo "Erstelle /var/lib/wakeup-check..."
    mkdir -p /var/lib/wakeup-check
    chmod 755 /var/lib/wakeup-check
else
    echo "Verzeichnis /var/lib/wakeup-check existiert bereits."
fi

# Log-Datei
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    echo "Log-Datei wurde unter $LOG_FILE erstellt."
else
    echo "Log-Datei existiert bereits."
fi

# Timestamp-Datei
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch "$WAKE_TIMESTAMP_FILE"
    chmod 644 "$WAKE_TIMESTAMP_FILE"
    echo "Timestamp-Datei wurde unter $WAKE_TIMESTAMP_FILE erstellt."
else
    echo "Timestamp-Datei existiert bereits."
fi

# Helligkeits-Datei
if [ ! -f "$BRIGHTNESS_STORE_FILE" ]; then
    touch "$BRIGHTNESS_STORE_FILE"
    chmod 644 "$BRIGHTNESS_STORE_FILE"
    echo "Helligkeitsdatei wurde unter $BRIGHTNESS_STORE_FILE erstellt."
else
    echo "Helligkeitsdatei existiert bereits."
fi

# Konfigurationsdatei installieren
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH existiert bereits."
    read -p "Möchten Sie die Konfigurationsdatei überschreiben? (y/N): " overwrite_conf
    if [[ "$overwrite_conf" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_SOURCE" "$CONFIG_PATH"
        chmod 644 "$CONFIG_PATH"
        echo "Konfigurationsdatei wurde unter $CONFIG_PATH überschrieben."
    else
        echo "Behalte die bestehende Konfigurationsdatei."
    fi
else
    echo "Installiere Konfigurationsdatei nach $CONFIG_PATH..."
    cp "$CONFIG_SOURCE" "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
    echo "Konfigurationsdatei wurde installiert."
fi

# Installiere systemd Services
echo "Installiere systemd Services für Wakeup-Check..."

# Pre-Suspend Service
if [ ! -f "$PRE_SERVICE_PATH" ]; then
    cp "$PRE_SERVICE_SOURCE" "$PRE_SERVICE_PATH"
    echo "Pre-Suspend Service installiert unter $PRE_SERVICE_PATH."
else
    echo "$PRE_SERVICE_PATH existiert bereits."
    read -p "Möchten Sie den Pre-Suspend Service überschreiben? (y/N): " overwrite_pre
    if [[ "$overwrite_pre" =~ ^[Yy]$ ]]; then
        cp "$PRE_SERVICE_SOURCE" "$PRE_SERVICE_PATH"
        echo "Pre-Suspend Service wurde überschrieben."
    else
        echo "Behalte bestehenden Pre-Suspend Service."
    fi
fi

# Post-Resume Service
if [ ! -f "$POST_SERVICE_PATH" ]; then
    cp "$POST_SERVICE_SOURCE" "$POST_SERVICE_PATH"
    echo "Post-Resume Service installiert unter $POST_SERVICE_PATH."
else
    echo "$POST_SERVICE_PATH existiert bereits."
    read -p "Möchten Sie den Post-Resume Service überschreiben? (y/N): " overwrite_post
    if [[ "$overwrite_post" =~ ^[Yy]$ ]]; then
        cp "$POST_SERVICE_SOURCE" "$POST_SERVICE_PATH"
        echo "Post-Resume Service wurde überschrieben."
    else
        echo "Behalte bestehenden Post-Resume Service."
    fi
fi

# systemd neuladen und Dienste aktivieren
echo "Aktualisiere systemd und aktiviere Dienste..."
systemctl daemon-reload
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service

echo "Installation abgeschlossen."
