#!/bin/bash
check_dependencies
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

check_dependencies() {
    local dependencies=(logger jq gdbus grep awk sed)

    echo "== Prüfe Abhängigkeiten =="

    local missing=0
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Fehler: '$dep' ist nicht installiert oder nicht im PATH."
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo "Bitte installiere die fehlenden Abhängigkeiten und versuche es erneut."
        exit 1
    fi
}

turn_off_display() {
    log "turn_off_display() called, DISPLAY_CONTROL_METHOD=$DISPLAY_CONTROL_METHOD"

    case "$DISPLAY_CONTROL_METHOD" in
        brightness)
            log "Turning off display via brightness method..."
            if [ -f "$BRIGHTNESS_PATH" ]; then
                SAVED_BRIGHTNESS=$(cat "$BRIGHTNESS_PATH")
                log "Current brightness read as: $SAVED_BRIGHTNESS"

                # Only save the brightness value if it's not zero
                if [ "$SAVED_BRIGHTNESS" -ne 0 ]; then
                    if echo "$SAVED_BRIGHTNESS" > "$BRIGHTNESS_SAVE_PATH"; then
                        log "Saved brightness value $SAVED_BRIGHTNESS to $BRIGHTNESS_SAVE_PATH"
                    else
                        log "Failed to write brightness value to $BRIGHTNESS_SAVE_PATH"
                    fi
                else
                    log "Current brightness is 0, not saving."
                fi

                # Turn off the display by setting brightness to 0
                if echo 0 > "$BRIGHTNESS_PATH"; then
                    log "Brightness successfully set to 0"
                else
                    log "Failed to set brightness to 0"
                fi
            else
                log "Brightness path $BRIGHTNESS_PATH not found."
            fi
            ;;
        screensaver)
            log "Turning off display via GNOME ScreenSaver D-Bus..."
            if sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                gdbus call --session \
                --dest org.gnome.ScreenSaver \
                --object-path /org/gnome/ScreenSaver \
                --method org.gnome.ScreenSaver.SetActive true >/dev/null; then
                log "Display locked via org.gnome.ScreenSaver.SetActive(true)"
            else
                log "Failed to lock display via D-Bus"
            fi
            ;;
        *)
            log "Unknown DISPLAY_CONTROL_METHOD: $DISPLAY_CONTROL_METHOD — check config file"
            ;;
    esac
}

turn_on_display() {
    log "turn_on_display() called, DISPLAY_CONTROL_METHOD=$DISPLAY_CONTROL_METHOD"

    case "$DISPLAY_CONTROL_METHOD" in
        brightness)
            log "Turning on display via brightness method..."

            # Standardwert setzen
            BRIGHTNESS=100

            if [ -f "$BRIGHTNESS_SAVE_PATH" ] && [ -s "$BRIGHTNESS_SAVE_PATH" ]; then
                SAVED_BRIGHTNESS=$(cat "$BRIGHTNESS_SAVE_PATH")
                log "Read saved brightness value: $SAVED_BRIGHTNESS"

                # Wenn die gespeicherte Helligkeit 0 ist, behalten wir 100 bei.
                if [ "$SAVED_BRIGHTNESS" -ne 0 ]; then
                    BRIGHTNESS="$SAVED_BRIGHTNESS"
                else
                    log "Saved brightness value is 0, keeping brightness at 100%"
                fi
            else
                log "No saved brightness value found or file is empty, setting brightness to $BRIGHTNESS"
            fi

            # Setze die Helligkeit auf den ermittelten Wert
            if echo "$BRIGHTNESS" > "$BRIGHTNESS_PATH"; then
                log "Brightness set to $BRIGHTNESS"
            else
                log "Failed to set brightness to $BRIGHTNESS"
            fi
            ;;
        screensaver)
            log "Turning on display via GNOME ScreenSaver D-Bus..."
            if sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                gdbus call --session \
                --dest org.gnome.ScreenSaver \
                --object-path /org/gnome/ScreenSaver \
                --method org.gnome.ScreenSaver.SetActive false >/dev/null; then
                log "Display unlock requested via org.gnome.ScreenSaver.SetActive(false)"
            else
                log "Failed to unlock display via D-Bus"
            fi
            ;;
        *)
            log "Unknown DISPLAY_CONTROL_METHOD: $DISPLAY_CONTROL_METHOD — check config file"
            ;;
    esac
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

handle_notification_actions() {
    if [[ "$NOTIFICATION_TURN_ON_DISPLAY" == "true" ]]; then
        log "Turning display on due to notification..."
        turn_on_display
    fi

    if [[ "$NOTIFICATION_USE_FBCLI" == "true" ]]; then
        log "Calling fbcli due to notification..."
        use_fbcli
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

    # Wenn QUIET_HOURS_END nach Mitternacht geht
    if [[ "$QUIET_HOURS_END" > "$QUIET_HOURS_START" ]]; then
        # Ruhezeit geht am selben Tag zu Ende
        end_ts=$(date -d "$today $QUIET_HOURS_END" +%s)
    else
        # Ruhezeit geht über Mitternacht hinaus
        end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    echo "Current time: $(date -d @$now)"
    echo "Start time: $(date -d @$start_ts)"
    echo "End time: $(date -d @$end_ts)"

    # Überprüfen, ob wir uns in den ruhigen Stunden befinden
    if (( now >= start_ts && now < end_ts )); then
        return 0  # In den ruhigen Stunden
    else
        return 1  # Nicht in den ruhigen Stunden
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

    log "Setting RTC Wakeup"
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
        sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
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
                exit 0
            else
                log "Disallowed notification from: $check_entry"
            fi
        fi
    done

    log "Notification monitor timed out without match."
    return 124
}

# ---------- MAIN ----------
MODE="$1"
log "===== wakeup-check.sh started (mode: $MODE) ====="

if [[ "$MODE" == "post" ]]; then
    turn_off_display
    log "System woke up from standby."
    log "Checking for RTC wake..."
    if is_rtc_wakeup; then
        log "RTC wake detected."

        if is_quiet_hours; then
            log "Currently in quiet hours - suspending again."
            log "===== wakeup-check.sh finished (mode: $MODE) ====="
            sync
            sleep 2
            systemctl suspend
            exit 0
        fi

        if wait_for_internet; then
            log "Internet OK"

            if monitor_notifications; then
                log "Relevant notification received staying awake"
                handle_notification_actions
            elif [[ $? -eq 124 ]]; then
                log "Notification timeout reached - suspending again."
                log "===== wakeup-check.sh finished (mode: $MODE) ====="
                sync
                sleep 2
                systemctl suspend
                exit 0
            else
                log "Notification monitor exited unexpectedly - suspending."
                log "===== wakeup-check.sh finished (mode: $MODE) ====="
                sync
                sleep 2
                systemctl suspend
                exit 0
            fi
        else
            log "No internet - suspending."
            log "===== wakeup-check.sh finished (mode: $MODE) ====="
            sync
            sleep 2
            systemctl suspend
            exit 0
        fi
    else
        log "Not an RTC wake - staying awake and turning display on."
        turn_on_display
    fi

    log "===== wakeup-check.sh finished (mode: $MODE) ====="
    sync
    sleep 2
    exit 0
fi

if [[ "$MODE" == "pre" ]]; then
    turn_off_display
    sleep 1
    set_rtc_wakeup
    log "Pre-mode done."
    log "===== wakeup-check.sh (mode: $MODE) finished ====="
    sync
    sleep 2
    exit 0
fi
