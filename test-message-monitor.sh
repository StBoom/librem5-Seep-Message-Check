#!/bin/bash

# Testscript zum Überwachen von Nachrichten für eine bestimmte Zeit (z. B. 120 Sekunden)

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SCRIPT="$SCRIPT_DIR/wakeup-check.sh"
CONFIG_FILE="/etc/wakeup-check.conf"
MONITOR_DURATION=120  # Zeit in Sekunden

# Prüfe, ob das Hauptscript existiert und ausführbar ist
if [ ! -x "$SCRIPT" ]; then
    echo "Fehler: $SCRIPT ist nicht ausführbar oder existiert nicht."
    echo "Bitte stelle sicher, dass es vorhanden und mit chmod +x ausführbar gemacht wurde."
    exit 1
fi

# Quell die Konfigurationsdatei, falls vorhanden
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Warnung: Konfigurationsdatei $CONFIG_FILE wurde nicht gefunden. Standardwerte werden verwendet."
fi

echo "== Test: Monitoring messages for $MONITOR_DURATION seconds =="
echo "You now have $MONITOR_DURATION seconds to send a test message/notification..."
echo "Monitoring started at $(date)"
echo

# Starte das Monitoring mit Timeout
timeout "$MONITOR_DURATION" bash -c "
    source \"$SCRIPT\"
    monitor_notifications
"

echo
echo "== Test ended at $(date) =="
