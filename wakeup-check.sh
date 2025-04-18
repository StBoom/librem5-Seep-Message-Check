#!/bin/bash

# Konfigurationsdatei
CONFIG_FILE="/etc/wakeup-check.conf"
[ ! -f "$CONFIG_FILE" ] && echo "Fehlende Konfigurationsdatei: $CONFIG_FILE" && exit 1
source "$CONFIG_FILE"

# Zielbenutzer UID & DBus-Session prüfen
TARGET_UID=$(id -u "$TARGET_USER")
if [ ! -d "/run/user/${TARGET_UID}" ]; then
    echo "DBus-Session für Benutzer ${TARGET_USER} nicht gefunden!"
    exit 1
fi
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

turn_off_display() {
    log "Bildschirm ausschalten"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive true >/dev/null
}

turn_on_display() {
    log "Bildschirm einschalten"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive false >/dev/null
}

use_fbcli() {
    if [ "$NOTIFICATION_USE_FBCLI" == "true" ]; then
        log "fbcli für Benachrichtigung verwenden."
        sudo -u "$TARGET_USER" fbcli -E notification-missed-generic
        sudo -u "$TARGET_USER" fbcli -E message-new-instant
    fi
}

is_quiet_hours() {
    now=$(date +%H:%M)
    if [[ "$QUIET_HOURS_START" < "$QUIET_HOURS_END" ]]; then
        [[ "$now" > "$QUIET_HOURS_START" && "$now" < "$QUIET_HOURS_END" ]]
    else
        [[ "$now" > "$QUIET_HOURS_START" || "$now" < "$QUIET_HOURS_END" ]]
    fi
}

get_next_alarm_time() {
    local alarms=$(gdbus call --session \
        --dest org.gnome.clocks \
        --object-path /org/gnome/clocks/AlarmModel \
        --method org.gnome.clocks.AlarmModel.ListAlarms | grep -oP '\d{10}')
    local now=$(date +%s)
    local next_alarm=0

    for ts in $alarms; do
        if (( ts > now )); then
            if (( next_alarm == 0 || ts < next_alarm )); then
                next_alarm=$ts
            fi
        fi
    done

    echo "$next_alarm"
}

is_rtc_wakeup() {
    [ -f "$WAKE_TIMESTAMP_FILE" ] || return 1

    local last_wake now diff
    last_wake=$(cat "$WAKE_TIMESTAMP_FILE")
    now=$(date +%s)
    diff=$((now - last_wake))

    log "Last RTC wake: ${last_wake} ($(date -d @${last_wake}))"
    log "Now:           ${now} ($(date -d @${now}))"
    log "Diff:          ${diff} Sekunden"

    # true nur, wenn der gespeicherte Wake-Zeitpunkt in der Vergangenheit
    # liegt und nicht länger als RTC_WAKE_WINDOW_SECONDS her ist
    (( diff >= 0 && diff <= RTC_WAKE_WINDOW_SECONDS ))
}

set_rtc_wakeup() {
    local now=$(date +%s)
    local interval=$(( NEXT_RTC_WAKE_MIN * 60 ))
    local wake_ts=$(( now + interval ))

    echo "$wake_ts" > "$WAKE_TIMESTAMP_FILE"
    log "RTC-Wakeup geplant auf $(date -d @${wake_ts}) (Timestamp $wake_ts)"

    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo "$wake_ts" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
}

wait_for_internet() {
    log "Warte bis zu $MAX_WAIT Sekunden auf Internetverbindung..."
    for ((i=0; i<MAX_WAIT; i++)); do
        status=$(nmcli networking connectivity)
        log "nmcli: $status"
        if [[ "$status" == "full" ]]; then
            log "Internetverbindung verfügbar."
            return 0
        fi
        sleep 1
    done

    if ping -q -c 1 -W 2 "$PING_HOST" >/dev/null; then
        log "Ping erfolgreich – Internet wahrscheinlich verfügbar."
        return 0
    fi

    log "Keine Internetverbindung erkannt."
    return 1
}

monitor_notifications() {
    local whitelist=($APP_WHITELIST)

    timeout "$NOTIFICATION_TIMEOUT" sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    dbus-monitor "interface='org.freedesktop.Notifications'" |
    while read -r line; do
        if echo "$line" | grep -q "member=Notify"; then
            buffer=""
            for _ in {1..6}; do
                read -r next && buffer+="$next"$'\n'
            done
            app=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | head -1 | tr '[:upper:]' '[:lower:]')
            summary=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | sed -n '3p')
            body=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | sed -n '4p')
            log "Benachrichtigung empfangen von: $app"
            log "Titel: $summary"
            log "Nachricht: $body"

            local is_relevant=0
            if [[ "$NOTIFICATION_MODE" == "all" ]]; then
                is_relevant=1
                log "Benachrichtigung akzeptiert (Modus: all)"
            else
                for match in "${whitelist[@]}"; do
                    if [[ "$app" == *"$match"* ]]; then
                        is_relevant=1
                        log "Relevante Benachrichtigung von: $app (Modus: whitelist)"
                        break
                    fi
                done
            fi

            if (( is_relevant == 1 )); then
                if [ "$NOTIFICATION_TURN_ON_DISPLAY" == "true" ]; then
                    turn_on_display
                fi
                use_fbcli
                echo "NOTIFIED"
                return 0
            else
                log "Nicht relevante Benachrichtigung ignoriert."
            fi
        fi
    done

    return 1
}

# ---------- HAUPTLOGIK ----------
turn_off_display
MODE="$1"
log "===== wakeup-check.sh started (mode: $MODE) ====="

if [[ "$MODE" == "pre" ]]; then
    set_rtc_wakeup
    log "Pre-mode done."
    log "===== wakeup-check.sh finished ====="
    systemctl suspend
    exit 0
fi

# ----------- Post-Mode ------------
if [[ "$MODE" == "post" ]]; then
  log "Checking for RTC wake..."
  if is_rtc_wakeup; then
      log "RTC wake detected."

      if is_quiet_hours; then
          log "Currently in quiet hours – no action taken."
          set_rtc_wakeup
          systemctl suspend
          exit 0
      fi

      if wait_for_internet; then
          log "Internet OK – monitoring notifications..."
          TMP_NOTIFY_FILE=$(mktemp)
          (monitor_notifications > "$TMP_NOTIFY_FILE") &
          sleep "$NOTIFICATION_TIMEOUT"
          wait
          if grep -q "NOTIFIED" "$TMP_NOTIFY_FILE"; then
              log "Relevant notification found – staying awake."
          else
              log "No relevant notification – suspending again."
              set_rtc_wakeup
              systemctl suspend
          fi
          rm -f "$TMP_NOTIFY_FILE"
      else
          log "No internet – suspending."
          set_rtc_wakeup
          systemctl suspend
      fi
  else
      log "Not an RTC wake – system stays awake."
  fi
fi
log "===== wakeup-check.sh finished ====="
