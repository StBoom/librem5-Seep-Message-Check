#!/bin/bash

# Load configuration
CONFIG_FILE="/etc/wakeup-check.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Missing config file: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

TARGET_UID=$(id -u "$TARGET_USER")
if [ ! -d "/run/user/${TARGET_UID}" ]; then
    echo "[ERROR] DBus session for user $TARGET_USER not found"
    exit 1
fi
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"

log() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOGFILE"
}

turn_off_display() {
    log "Turning off display"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive true >/dev/null
}

turn_on_display() {
    log "Turning on display"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive false >/dev/null
}

use_fbcli() {
    if [ "$NOTIFICATION_USE_FBCLI" == "true" ]; then
        log "Using fbcli for notification"
        sudo -u "$TARGET_USER" fbcli -E notification-missed-generic
        sudo -u "$TARGET_USER" fbcli -E message-new-instant
    fi
}

is_quiet_hours() {
    now_seconds=$(date +%s)
    today=$(date +%Y-%m-%d)
    start_seconds=$(date -d "$today $QUIET_HOURS_START" +%s)
    end_seconds=$(date -d "$today $QUIET_HOURS_END" +%s)

    if [[ "$start_seconds" -lt "$end_seconds" ]]; then
        result=$(( now_seconds >= start_seconds && now_seconds < end_seconds ))
    else
        result=$(( now_seconds >= start_seconds || now_seconds < end_seconds ))
    fi

    return $result
}

is_rtc_wakeup() {
    if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
        log "No wake timestamp file found – not an RTC wake."
        return 1
    fi

    local timestamp_file_ts rtc_now diff
    rtc_now=$(date +%s)
    timestamp_file_ts=$(cat "$WAKE_TIMESTAMP_FILE")

    if ! [[ "$timestamp_file_ts" =~ ^[0-9]+$ ]]; then
        log "Invalid timestamp in file: $timestamp_file_ts"
        return 1
    fi

    diff=$((rtc_now - timestamp_file_ts))

    if (( diff >= 0 && diff <= RTC_WAKE_WINDOW_SECONDS )); then
        log "RTC wake confirmed"
        return 0
    else
        log "Not an RTC wake"
        return 1
    fi
}

set_rtc_wakeup() {
    local now wake_ts quiet_end_ts next_alarm_ts adjusted_wake_ts
    now=$(date +%s)

    # Quiet hours Ende berechnen
    if [[ "$QUIET_HOURS_START" < "$QUIET_HOURS_END" ]]; then
        quiet_end_ts=$(date -d "today $QUIET_HOURS_END" +%s)
    else
        quiet_end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    # Nächsten Alarm abrufen
    next_alarm_ts=$(get_next_alarm_time)

    if [[ -z "$next_alarm_ts" || ! "$next_alarm_ts" =~ ^[0-9]+$ ]]; then
        log "No upcoming alarm found – fallback to quiet end."
        next_alarm_ts=$(( quiet_end_ts + 1 ))
    fi

    # RTC Wakeup Zeit setzen (vor dem nächsten Alarm oder Ende der Quiet Hours)
    if is_quiet_hours; then
        log "Currently in quiet hours."
        wake_ts=$quiet_end_ts
        log "No alarm during quiet hours. Setting RTC wakeup for end of quiet hours: $(date -d @$wake_ts)"
    else
        wake_ts=$(( now + (NEXT_RTC_WAKE_MIN * 60) ))
        log "Not in quiet hours. Setting RTC wakeup for $(date -d @$wake_ts)"
    fi

    # Prüfen, ob ein Alarm in der Zeit bis zum nächsten RTC Wakeup liegt
    if [[ "$next_alarm_ts" -gt $now && "$next_alarm_ts" -lt $wake_ts ]]; then
        adjusted_wake_ts=$((next_alarm_ts - (WAKE_BEFORE_ALARM_MINUTES * 60)))
        log "Alarm found before RTC wakeup. Adjusting wake time to: $(date -d @$adjusted_wake_ts)"
        wake_ts=$adjusted_wake_ts
    fi

    # RTC Wakeup auf die berechnete Zeit setzen
    if ! echo "$wake_ts" > "$WAKE_TIMESTAMP_FILE"; then
        log "[ERROR] Failed to write to wake timestamp file."
        exit 1
    fi
    if ! echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || ! echo "$wake_ts" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null; then
        log "[ERROR] Failed to set RTC wake alarm."
        exit 1
    fi

    log "RTC wakeup set to $(date -d @$wake_ts)"

    # RTC wakealarm und timestamp datei abgleichen
    rtc_actual=$(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null)
    if [[ "$rtc_actual" == "$wake_ts" ]]; then
        log "RTC wakealarm and timestamp file match: $wake_ts"
    else
        log "[WARNING] Mismatch: RTC wakealarm=$rtc_actual, timestamp file=$wake_ts"
    fi
}

get_next_alarm_time() {
    alarm_time=$(sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.clocks \
        --object-path /org/gnome/clocks/AlarmModel \
        --method org.gnome.clocks.AlarmModel.ListAlarms 2>/dev/null |
        grep -oP '\\d{10}' | sort -n | head -1)

    echo "$alarm_time"
}

wait_for_internet() {
    log "Waiting up to $MAX_WAIT seconds for internet..."
    for ((i=0; i<MAX_WAIT; i++)); do
        status=$(nmcli networking connectivity)
        if [[ "$status" == "full" ]]; then
            log "Internet connection is available"
            return 0
        fi
        sleep 1
    done

    if ping -q -c 1 -W 2 "$PING_HOST" >/dev/null; then
        log "Ping successful – internet likely available"
        return 0
    fi

    log "No internet connection detected"
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
            log "Notification received from: $app"
            log "Title: $summary"
            log "Message: $body"

            local is_relevant=0
            if [[ "$NOTIFICATION_MODE" == "all" ]]; then
                is_relevant=1
            else
                for match in "${whitelist[@]}"; do
                    if [[ "$app" == *"$match"* ]]; then
                        is_relevant=1
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
            fi
        fi
    done

    return 1
}

# ---------- MAIN ----------
turn_off_display
MODE="$1"
log "===== wakeup-check.sh started (mode: $MODE) ====="

if [[ "$MODE" == "pre" ]]; then
    set_rtc_wakeup
    log "Pre-mode done."
    log "===== wakeup-check.sh finished ====="
    exit 0
fi

if [[ "$MODE" == "post" ]]; then
    log "System woke up from standby."
    log "Checking for RTC wake..."
    if is_rtc_wakeup; then
        log "RTC wake detected."

        if is_quiet_hours; then
            log "Currently in quiet hours – set rtc wakeup (after quiet hours)"
            systemctl suspend
            exit 0
        fi

        if wait_for_internet; then
            log "Internet OK – monitoring notifications..."
            TMP_NOTIFY_FILE=$(mktemp)
            (monitor_notifications > "$TMP_NOTIFY_FILE") &
            MONITOR_PID=$!
            sleep "$NOTIFICATION_TIMEOUT"
            wait $MONITOR_PID
            if grep -q "NOTIFIED" "$TMP_NOTIFY_FILE"; then
                log "Relevant notification found – staying awake."
            else
                log "No relevant notification – suspending again."
                systemctl suspend
            fi
            rm -f "$TMP_NOTIFY_FILE"
        else
            log "No internet – suspending."
            systemctl suspend
        fi
    else
        turn_on_display
        log "Not an RTC wake – system stays awake. Turn display on"
    fi
    log "===== wakeup-check.sh finished ====="
    exit 0
fi
