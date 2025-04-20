#!/bin/bash

# Installationsverzeichnis
REPO_DIR="$(pwd)"

# Zielverzeichnisse
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
CONF_DIR="/etc"
WAKEUP_CHECK_SCRIPT="wakeup-check.sh"
SERVICE_FILE="wakeup-check-pre.service"
CONF_FILE="wakeup-check.conf"
LOG_DIR="/var/log/wakeup-check"
WAKE_TIMESTAMP_FILE="$LOG_DIR/wake_timestamp"
LOG_FILE="$LOG_DIR/wakeup-check.log"

# Hilfsfunktion: Log-Nachricht
log() {
    echo "[INFO] $1"
}

# Prüfen, ob das Skript mit root-Rechten ausgeführt wird
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Dieses Skript muss als root ausgeführt werden!" 
    exit 1
fi

# 1. Kopiere das Haupt-Skript in das Zielverzeichnis
log "Kopiere $WAKEUP_CHECK_SCRIPT nach $BIN_DIR"
cp "$REPO_DIR/$WAKEUP_CHECK_SCRIPT" "$BIN_DIR/$WAKEUP_CHECK_SCRIPT"

# 2. Kopiere die systemd-Dienstdatei
log "Kopiere $SERVICE_FILE nach $SERVICE_DIR"
cp "$REPO_DIR/$SERVICE_FILE" "$SERVICE_DIR/$SERVICE_FILE"

# 3. Kopiere die Konfigurationsdatei
log "Kopiere $CONF_FILE nach $CONF_DIR"
cp "$REPO_DIR/$CONF_FILE" "$CONF_DIR/$CONF_FILE"

# 4. Setze die richtigen Berechtigungen für das Skript
log "Setze Ausführungsrechte für $WAKEUP_CHECK_SCRIPT"
chmod +x "$BIN_DIR/$WAKEUP_CHECK_SCRIPT"

# 5. Setze die richtigen Berechtigungen für die systemd-Dienstdatei
log "Setze die richtigen Berechtigungen für den systemd-Dienst"
chmod 644 "$SERVICE_DIR/$SERVICE_FILE"

# 6. Erstelle das Verzeichnis für Logs, falls es noch nicht existiert
log "Erstelle Verzeichnis für Logs, falls noch nicht vorhanden"
mkdir -p "$LOG_DIR"

# 7. Erstelle die Logdatei, falls sie noch nicht existiert
log "Erstelle Logdatei, falls noch nicht vorhanden"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log "Logdatei erstellt: $LOG_FILE"
else
    log "Logdatei existiert bereits."
fi

# 8. Setze die richtigen Berechtigungen für die Logdatei
log "Setze die richtigen Berechtigungen für die Logdatei"
chmod 640 "$LOG_FILE"  # Root (Schreibrecht) + Gruppe (Leserecht)

# 9. Erstelle die Zeitstempel-Datei, falls sie nicht existiert
log "Erstelle die Zeitstempel-Datei, falls sie noch nicht existiert"
if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
    touch "$WAKE_TIMESTAMP_FILE"
    log "Zeitstempel-Datei erstellt: $WAKE_TIMESTAMP_FILE"
else
    log "Zeitstempel-Datei existiert bereits."
fi

# 10. Setze die richtigen Berechtigungen für die Zeitstempel-Datei
log "Setze die richtigen Berechtigungen für die Zeitstempel-Datei"
chmod 640 "$WAKE_TIMESTAMP_FILE"  # Root (Schreibrecht) + Gruppe (Leserecht)

# 11. Systemd-Dienst aktivieren
log "Aktiviere systemd-Dienst wakeup-check-pre.service"
systemctl enable "$SERVICE_DIR/$SERVICE_FILE"

# 12. Starte den systemd-Dienst
log "Starte den systemd-Dienst wakeup-check-pre.service"
systemctl start wakeup-check-pre.service

# 13. Überprüfen, ob der Dienst läuft
log "Überprüfe, ob der systemd-Dienst korrekt läuft"
systemctl status wakeup-check-pre.service

log "Installation abgeschlossen!"
