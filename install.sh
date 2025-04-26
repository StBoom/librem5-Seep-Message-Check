#!/bin/bash

# Installer für Wakeup Check Service (angepasst für systemd sleep hooks)

# Define paths
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"
SLEEP_HOOK_PATH="/lib/systemd/system-sleep/wakeup-check"
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

# Helligkeits-Datei (zum Speichern der Helligkeit vor dem Display-Ausschalten)
if [ ! -f "$BRIGHTNESS_STORE_FILE" ]; then
    touch $BRIGHTNESS_STORE_FILE
    chmod 644 $BRIGHTNESS_STORE_FILE
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

# Installiere systemd sleep hook (anstelle der systemd Services)
echo "Installiere systemd Sleep Hook..."

if [ ! -f "$SLEEP_HOOK_PATH" ]; then
    cp wakeup-check.sh "$SLEEP_HOOK_PATH"
    chmod +x "$SLEEP_HOOK_PATH"
    echo "Sleep Hook-Skript wurde unter $SLEEP_HOOK_PATH installiert."
else
    echo "$SLEEP_HOOK_PATH existiert bereits. Überspringe Kopieren."
fi
