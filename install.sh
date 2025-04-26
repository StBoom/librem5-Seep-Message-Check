#!/bin/bash

# ---- Pfade definieren ----
SCRIPT_NAME="wakeup-check.sh"
SCRIPT_SOURCE="./$SCRIPT_NAME"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"

LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
BRIGHTNESS_STORE_FILE="/var/lib/wakeup-check/last_brightness"

PRE_SERVICE_NAME="wakeup-check-pre.service"
PRE_SERVICE_SOURCE="./$PRE_SERVICE_NAME"
PRE_SERVICE_PATH="/etc/systemd/system/$PRE_SERVICE_NAME"

CONFIG_SOURCE="./wakeup-check.conf"
CONFIG_PATH="/etc/wakeup-check.conf"

HOOK_SOURCE="./wakeup-check-post.sh"
SYSTEM_SLEEP_HOOK="/lib/systemd/system-sleep/wakeup-check-post.sh"

# ---- Helper-Funktion: Root-Rechte prüfen ----
if [ "$EUID" -ne 0 ]; then
    echo "Bitte als root oder mit sudo ausführen!"
    exit 1
fi

# ---- Skript kopieren ----
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

# ---- Rechte für das Skript setzen ----
if [ -f "$SCRIPT_PATH" ]; then
    chmod 755 "$SCRIPT_PATH"
    chown root:root "$SCRIPT_PATH"
else
    echo "Fehler: Skript nicht gefunden unter $SCRIPT_PATH. Abbruch."
    exit 1
fi

# ---- Verzeichnisse und Dateien vorbereiten ----
echo "Erstelle notwendige Verzeichnisse und Dateien..."

mkdir -p /var/lib/wakeup-check
chmod 755 /var/lib/wakeup-check

[ -f "$LOG_FILE" ] || { touch "$LOG_FILE"; chmod 644 "$LOG_FILE"; }

[ -f "$WAKE_TIMESTAMP_FILE" ] || { touch "$WAKE_TIMESTAMP_FILE"; chmod 644 "$WAKE_TIMESTAMP_FILE"; }
[ -f "$BRIGHTNESS_STORE_FILE" ] || { touch "$BRIGHTNESS_STORE_FILE"; chmod 644 "$BRIGHTNESS_STORE_FILE"; }

# ---- Konfigurationsdatei installieren ----
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH existiert bereits."
    read -p "Möchten Sie die Konfigurationsdatei überschreiben? (y/N): " overwrite_conf
    if [[ "$overwrite_conf" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_SOURCE" "$CONFIG_PATH"
        chmod 644 "$CONFIG_PATH"
        echo "Konfigurationsdatei wurde überschrieben."
    else
        echo "Behalte die bestehende Konfigurationsdatei."
    fi
else
    echo "Installiere Konfigurationsdatei nach $CONFIG_PATH..."
    cp "$CONFIG_SOURCE" "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
    echo "Konfigurationsdatei wurde installiert."
fi

# ---- Pre-Suspend systemd Service installieren ----
echo "Installiere systemd Pre-Suspend Service..."

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

# ---- system-sleep Hook für Post-Resume installieren ----
echo "Installiere system-sleep Hook für Post-Resume..."

if [ ! -f "$SYSTEM_SLEEP_HOOK" ]; then
    cp "$HOOK_SOURCE" "$SYSTEM_SLEEP_HOOK"
    chmod 755 "$SYSTEM_SLEEP_HOOK"
    chown root:root "$SYSTEM_SLEEP_HOOK"
    echo "Hook wurde kopiert nach $SYSTEM_SLEEP_HOOK."
else
    echo "$SYSTEM_SLEEP_HOOK existiert bereits."
    read -p "Möchten Sie den Hook überschreiben? (y/N): " overwrite_hook
    if [[ "$overwrite_hook" =~ ^[Yy]$ ]]; then
        cp "$HOOK_SOURCE" "$SYSTEM_SLEEP_HOOK"
        chmod 755 "$SYSTEM_SLEEP_HOOK"
        chown root:root "$SYSTEM_SLEEP_HOOK"
        echo "Hook wurde überschrieben unter $SYSTEM_SLEEP_HOOK."
    else
        echo "Behalte bestehenden Hook."
    fi
fi

# ---- systemd neu laden und Service aktivieren ----
echo "Aktualisiere systemd und aktiviere Pre-Suspend Service..."
systemctl daemon-reload
systemctl enable wakeup-check-pre.service

echo "Installation abgeschlossen."
