#!/bin/bash

# Load configuration
CONFIG_FILE="/etc/wakeup-check.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing config file: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Validate target user DBus session
TARGET_UID=$(id -u "$TARGET_USER")
if [ ! -d "/run/user/$TARGET_UID" ]; then
    echo "DBus session for user $TARGET_USER not found"
    exit 1
fi
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus"

# Logging helper
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# Turn display off
turn_off_display() {
    log "Turning off display"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive true >/dev/null 2>&1
}

# Turn display on
turn_on_display() {
    log "Turning on display"
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.SetActive false >/dev/null 2>&1
}

# Use fbcli for notifications if enabled
use_fbcli() {
    if [ "$NOTIFICATION_USE_FBCLI" == "true" ]; then
        log "Triggering fbcli notifications"
        sudo -u "$TARGET_USER" fbcli -E notification-missed-generic
        sudo -u "$TARGET_USER" fbcli -E message-new-instant
    fi
}

# Check if current time matches saved RTC wake timestamp
is_rtc_wakeup() {
    [ -f "$WAKE_TIMESTAMP_FILE" ] || return 1
    last_wake=$(cat "$WAKE_TIMESTAMP_FILE")
    now=$(date +%s)
    diff=$((now - last_wake))

    log "Last RTC wake: $last_wake ($(date -d @$last_wake))"
    log "Now:           $now ($(date -d @$now))"
    log "Diff:          $diff seconds"

    (( diff >= 0 && diff <= RTC_WAKE_WINDOW_SECONDS ))
}

# Determine if current time is within quiet hours
is_quiet_hours() {
    now=$(date +%H:%M)
    if [[ "$QUIET_HOURS_START" < "$QUIET_HOURS_END" ]]; then
        [[ "$now" > "$QUIET_HOURS_START" && "$now" < "$QUIET_HOURS_END" ]]
    else
        [[ "$now" > "$QUIET_HOURS_START" || "$now" < "$QUIET_HOURS_END" ]]
    fi
}

# Get next GNOME Clock alarm timestamp
get_next_alarm_time() {
    raw=$(sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gdbus call --session \
        --dest org.gnome.clocks \
        --object-path /org/gnome/clocks/AlarmModel \
        --method org.gnome.clocks.AlarmModel.ListAlarms 2>/dev/null)
    echo "$raw" | grep -oP '\d{10}' | sort -n | awk -v now="$(date +%s)" '$1 > now { print; exit }'
}

# Set RTC wake alarm with verification
set_rtc_wakeup() {
    now=$(date +%s)
    interval=$(( NEXT_RTC_WAKE_MIN * 60 ))
    wake_ts=$(( now + interval ))

    # Save to file
    echo "$wake_ts" > "$WAKE_TIMESTAMP_FILE"
    log "RTC wake scheduled for $(date -d @$wake_ts) (timestamp $wake_ts)"

    # Set hardware alarm
    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo "$wake_ts" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null

    # Verify alarm
    rtc_set=$(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null)
    if [[ "$rtc_set" != "$wake_ts" ]]; then
        log "WARNING: rtc wakealarm mismatch: set=$wake_ts, hw=$rtc_set"
    else
        log "RTC wakealarm confirmed: $rtc_set"
    fi

    # Verify file
    file_ts=$(cat "$WAKE_TIMESTAMP_FILE")
    if [[ "$file_ts" != "$wake_ts" ]]; then
        log "ERROR: timestamp file mismatch: saved=$file_ts, expected=$wake_ts"
    fi
}

# Wait for internet connectivity
wait_for_internet() {
    log "Waiting up to $MAX_WAIT seconds for internet..."
    for ((i=0; i<MAX_WAIT; i++)); do
        status=$(nmcli networking connectivity 2>/dev/null)
        log "nmcli status: $status"
        if [[ "$status" == "full" ]]; then
            log "Internet available"
            return 0
        fi
        sleep 1
    done
    if ping -c1 -W2 "$PING_HOST" &>/dev/null; then
        log "Ping successful"
        return 0
    fi
    log "No internet detected"
    return 1
}

# Monitor notifications and decide relevance
monitor_notifications() {
    whitelist=($APP_WHITELIST)
    timeout "$NOTIFICATION_TIMEOUT" sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        dbus-monitor "interface='org.freedesktop.Notifications'" >/dev/null 2>&1 |
    while read -r line; do
        if echo "$line" | grep -q "member=Notify"; then
            buffer=""
            for _ in {1..6}; do
                read -r next && buffer+="$next"$'\n'
            done
            app=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | head -1)
            summary=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | sed -n '3p')
            body=$(echo "$buffer" | grep -oP 'string "\K[^"]+' | sed -n '4p')
            log "Notification from: $app"
            log "Title: $summary"
            log "Body: $body"

            is_relevant=0
            if [[ "$NOTIFICATION_MODE" == "all" ]]; then
                is_relevant=1; log "Accepting notification (mode: all)"
            else
                for match in "${whitelist[@]}"; do
                    if [[ "${app,,}" == *"$match"* ]]; then
                        is_relevant=1; log "Relevant notification (mode: whitelist): $app"; break
                    fi
                done
            fi
            if (( is_relevant )); then
                (( NOTIFICATION_TURN_ON_DISPLAY == true )) && turn_on_display
                use_fbcli
                echo "NOTIFIED"
                return 0
            else
                log "Ignored non-relevant notification: $app"
            fi
        fi
    done
    return 1
}

# Main logic
turn_off_display
MODE="$1"
log "===== wakeup-check.sh started (mode: $MODE) ====="

if [[ "$MODE" == "pre" ]]; then
    set_rtc_wakeup
    log "Pre-mode complete"
    systemctl suspend
    exit 0
fi

if [[ "$MODE" == "post" ]]; then
    log "Checking for RTC wake..."
    if is_rtc_wakeup; then
        log "RTC wake detected"
        if is_quiet_hours; then
            log "Within quiet hours, skipping actions"
            set_rtc_wakeup
            systemctl suspend
            exit 0
        fi
        if wait_for_internet; then
            log "Monitoring notifications"
            TMP_FILE=$(mktemp)
            (monitor_notifications > "$TMP_FILE") & sleep "$NOTIFICATION_TIMEOUT"; wait
            if grep -q "NOTIFIED" "$TMP_FILE"; then
                log "Staying awake due to notification"
            else
                log "No relevant notifications -> suspending"
                set_rtc_wakeup
                systemctl suspend
            fi
            rm -f "$TMP_FILE"
        else
            log "No internet -> suspending"
            set_rtc_wakeup
            systemctl suspend
        fi
    else
        log "Not an RTC wake -> staying awake"
    fi
    log "Post-mode complete"
fi
