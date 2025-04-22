#!/bin/bash

# Load configuration
CONFIG_FILE="/etc/wakeup-check.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Missing config file: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Verify required variables are set
REQUIRED_VARS=(TARGET_USER LOGFILE QUIET_HOURS_START QUIET_HOURS_END WAKE_TIMESTAMP_FILE RTC_WAKE_WINDOW_SECONDS NEXT_RTC_WAKE_MIN PING_HOST NOTIFICATION_TIMEOUT)
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "[ERROR] Required config variable '$var' is not set."
        exit 1
    fi
done

TARGET_UID=$(id -u "$TARGET_USER")
if [ ! -d "/run/user/${TARGET_UID}" ]; then
    echo "[ERROR] DBus session for user $TARGET_USER not found"
    exit 1
fi
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"
XDG_RUNTIME_DIR="/run/user/${TARGET_UID}"

log() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" >> "$LOGFILE"
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
        if command -v fbcli >/dev/null 2>&1; then
            log "Using fbcli for notification"
            sudo -u "$TARGET_USER" fbcli -E notification-missed-generic
            sudo -u "$TARGET_USER" fbcli -E message-new-instant
        else
            log "fbcli not found, skipping fbcli notifications"
        fi
    fi
}

is_quiet_hours() {
    local test_time="$1"
    local now

    if [[ -n "$test_time" ]]; then
        now=$(date -d "$test_time" +%s)
    else
        now=$(date +%s)
    fi

    local today=$(date +%Y-%m-%d)
    local start_ts=$(date -d "$today $QUIET_HOURS_START" +%s)
    local end_ts

    if [[ "$QUIET_HOURS_END" > "$QUIET_HOURS_START" ]]; then
        end_ts=$(date -d "$today $QUIET_HOURS_END" +%s)
    else
        end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    if (( now >= start_ts && now < end_ts )); then
        return 0
    else
        return 1
    fi
}

is_rtc_wakeup() {
    if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
        log "No wake timestamp file found - not an RTC wake."
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
    local now=$(date +%s)
    local today=$(date +%Y-%m-%d)
    local start_ts end_ts quiet_end_ts
    local next_alarm_ts adjusted_wake_ts wake_ts

    log "=== Setting RTC Wakeup ==="
    log "Current time: $(date -d @$now +'%Y-%m-%d %H:%M:%S')"

    start_ts=$(date -d "$today $QUIET_HOURS_START" +%s)

    if [[ "$QUIET_HOURS_END" > "$QUIET_HOURS_START" ]]; then
        end_ts=$(date -d "$today $QUIET_HOURS_END" +%s)
    else
        end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    quiet_end_ts=$end_ts
    log "Quiet hours start: $(date -d @$start_ts +'%Y-%m-%d %H:%M:%S')"
    log "Quiet hours end:   $(date -d @$quiet_end_ts +'%Y-%m-%d %H:%M:%S')"

    next_alarm_ts=$(get_next_alarm_time)
    if [[ -n "$next_alarm_ts" && "$next_alarm_ts" =~ ^[0-9]+$ ]]; then
        log "Next alarm at: $(date -d @$next_alarm_ts +'%Y-%m-%d %H:%M:%S')"
    else
        log "No valid alarm found - skipping alarm adjustment"
        next_alarm_ts=""
    fi

    if is_quiet_hours; then
        log "Currently in quiet hours"
        wake_ts=$quiet_end_ts
        log "Setting wake time to end of quiet hours: $(date -d @$wake_ts)"
    else
        wake_ts=$(( now + (NEXT_RTC_WAKE_MIN * 60) ))
        log "Not in quiet hours - setting default RTC wake in ${NEXT_RTC_WAKE_MIN} minutes: $(date -d @$wake_ts)"
    fi

    if [[ -n "$next_alarm_ts" && "$next_alarm_ts" -gt "$now" && "$next_alarm_ts" -lt "$wake_ts" ]]; then
        adjusted_wake_ts=$(( next_alarm_ts - (WAKE_BEFORE_ALARM_MINUTES * 60) ))
        log "Alarm is earlier than current wake time - adjusting RTC wake to: $(date -d @$adjusted_wake_ts)"
        wake_ts=$adjusted_wake_ts
    fi

    if ! echo "$wake_ts" > "$WAKE_TIMESTAMP_FILE"; then
        log "[ERROR] Failed to write timestamp file: $WAKE_TIMESTAMP_FILE"
        exit 1
    fi

    if ! echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || ! echo "$wake_ts" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null; then
        log "[ERROR] Failed to set RTC wakealarm"
        exit 1
    fi

    log "RTC wakealarm set to: $(date -d @$wake_ts)"

    local rtc_actual=$(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null)
    if [[ "$rtc_actual" == "$wake_ts" ]]; then
        log "RTC wakealarm and saved timestamp match"
    else
        log "[WARNING] RTC wakealarm mismatch - actual: $rtc_actual, expected: $wake_ts"
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
        log "Ping successful - internet likely available"
        return 0
    fi

    log "No internet connection detected"
    return 1
}

is_whitelisted() {
    local entry="$1"
    for item in "${APP_WHITELIST[@]}"; do
        if [[ "${item,,}" == "${entry,,}" ]]; then
            return 0
        fi
    done
    return 1
}

get_app_name_from_desktop_entry() {
    local desktop_entry="$1"
    app_name=$(echo "$desktop_entry" | awk -F '.' '{print $NF}')
    echo "$app_name"
}

monitor_notifications() {
    local timeout_duration=${NOTIFICATION_TIMEOUT:-60}
    log "Monitoring notifications for $timeout_duration seconds..."

    timeout "$timeout_duration" \
        busctl --user monitor org.freedesktop.Notifications --json=short 2>/dev/null | \
    while IFS= read -r line; do
        if echo "$line" | grep -q '"member":"Notify"'; then
            app_name=$(echo "$line" | jq -r '.payload.data[0]' 2>/dev/null)
            desktop_entry=$(echo "$line" | jq -r '.payload.data[6]["desktop-entry"].data // empty' 2>/dev/null)

            if [[ -z "$desktop_entry" ]]; then
                check_entry="$app_name"
            else
                check_entry=$(get_app_name_from_desktop_entry "$desktop_entry")
            fi

            if is_whitelisted "$check_entry"; then
                log "Allowed notification from: $check_entry"
                kill "$$" 
            else
                log "Disallowed notification from: $check_entry"
            fi
        fi
    done

    log "Notification monitor timed out without match."
    return 124
}

# ---------- MAIN ----------
turn_off_display
MODE="$1"
log "===== wakeup-check.sh started (mode: $MODE) ====="

if [[ "$MODE" == "pre" ]]; then
    set_rtc_wakeup
    log "Pre-mode done."
    log "===== wakeup-check.sh finished ====="
    sleep 2
    exit 0
fi

if [[ "$MODE" == "post" ]]; then
    log "System woke up from standby."
    log "Checking for RTC wake..."

    if is_rtc_wakeup; then
        log "RTC wake detected."

        if is_quiet_hours; then
            log "Currently in quiet hours - suspending again."
            systemctl suspend
            exit 0
        fi

        if wait_for_internet; then
            log "Internet OK - monitoring notifications for $NOTIFICATION_TIMEOUT seconds..."

            if monitor_notifications; then
                log "Relevant notification received - staying awake."
                
            elif [[ $? -eq 124 ]]; then
                log "Notification timeout reached - suspending again."
                systemctl suspend
            else
                log "Notification monitor exited unexpectedly - suspending."
                systemctl suspend
            fi
        else
            log "No internet - suspending."
            systemctl suspend
        fi
    else
        log "Not an RTC wake - staying awake and turning display on."
        turn_on_display
    fi

    log "===== wakeup-check.sh finished ====="
    exit 0
fi
