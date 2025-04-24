#!/bin/bash

# Installer for Wakeup Check Service

check_and_install_dependencies() {
    echo "== Überprüfe und installiere benötigte Abhängigkeiten =="

    REQUIRED_PACKAGES=(jq gdbus grep awk sed)

    MISSING_PACKAGES=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ "${#MISSING_PACKAGES[@]}" -eq 0 ]; then
        echo "Alle benötigten Abhängigkeiten sind bereits installiert."
    else
        echo "Fehlende Pakete: ${MISSING_PACKAGES[*]}"
        if command -v apt &> /dev/null && [ "$EUID" -eq 0 ]; then
            echo "Versuche, fehlende Pakete mit apt zu installieren..."
            apt update && apt install -y "${MISSING_PACKAGES[@]}"
        else
            echo "Bitte installiere die fehlenden Pakete manuell:"
            echo "  sudo apt install ${MISSING_PACKAGES[*]}"
            exit 1
        fi
    fi
}

check_and_install_dependencies

# Pfade definieren
SCRIPT_PATH="/usr/local/bin/wakeup-check.sh"
LOG_FILE="/var/log/wakeup-check.log"
WAKE_TIMESTAMP_FILE="/var/lib/wakeup-check/last_wake_timestamp"
SERVICE_PRE_PATH="/etc/systemd/system/wakeup-check-pre.service"
SERVICE_POST_PATH="/etc/systemd/system/wakeup-check-post.service"
CONFIG_PATH="/etc/wakeup-check.conf"

# Sicherstellen, dass das Script vorhanden und ausführbar ist
echo "Setting executable permissions for $SCRIPT_PATH..."
chmod +x "$SCRIPT_PATH"

# Script kopieren, falls noch nicht vorhanden
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Copying wakeup-check.sh to $SCRIPT_PATH..."
    cp wakeup-check.sh "$SCRIPT_PATH"
else
    echo "$SCRIPT_PATH already exists. Skipping copy."
fi

# Verzeichnisse und Dateien anlegen
echo "Creating necessary directories and files..."
mkdir -p /var/lib/wakeup-check
chmod 755 /var/lib/wakeup-check

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

touch "$WAKE_TIMESTAMP_FILE"
chmod 644 "$WAKE_TIMESTAMP_FILE"

# Config-Datei prüfen/kopieren
if [ -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH already exists."
    read -p "Do you want to overwrite the existing config file? (y/N): " overwrite
    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
        cp wakeup-check.conf "$CONFIG_PATH"
        chmod 644 "$CONFIG_PATH"
        echo "Config file overwritten at $CONFIG_PATH."
    else
        echo "Keeping existing config file."
    fi
else
    echo "Copying wakeup-check.conf to $CONFIG_PATH..."
    cp wakeup-check.conf "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
fi

# Service-Dateien kopieren
echo "Installing systemd service files..."
if [ ! -f "$SERVICE_PRE_PATH" ]; then
    cp wakeup-check-pre.service "$SERVICE_PRE_PATH"
    chmod 644 "$SERVICE_PRE_PATH"
else
    echo "$SERVICE_PRE_PATH already exists. Skipping copy."
fi

if [ ! -f "$SERVICE_POST_PATH" ]; then
    cp wakeup-check-post.service "$SERVICE_POST_PATH"
    chmod 644 "$SERVICE_POST_PATH"
else
    echo "$SERVICE_POST_PATH already exists. Skipping copy."
fi

# Systemd neu laden und Services aktivieren
echo "Reloading systemd..."
systemctl daemon-reload

echo "Enabling systemd services..."
systemctl enable wakeup-check-pre.service
systemctl enable wakeup-check-post.service

echo "Installation complete. The services have been installed and enabled."
