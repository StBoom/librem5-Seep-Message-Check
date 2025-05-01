#!/bin/bash
#set -euo pipefail

# ====== Lockfile Management ======
LOCKFILE="/var/lock/wakeup-check.lock"

# Try to acquire the lock (wait if another instance is running)
exec 200>"$LOCKFILE"  # Öffne Datei mit Deskriptor 200

# Versuche, den Lock zu setzen, warte wenn eine andere Instanz läuft
flock 200 || { echo "[$(date +'%Y-%m-%d %H:%M:%S')] Another instance is already running. Waiting..."; flock 200; }

log() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" >> "$LOGFILE"
}

# Load configuration
CONFIG_FILE="/etc/wakeup-check.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    log "[ERROR] Missing config file: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Verify required variables are set
REQUIRED_VARS=(TARGET_USER LOGFILE QUIET_HOURS_START QUIET_HOURS_END WAKE_TIMESTAMP_FILE RTC_WAKE_WINDOW_SECONDS NEXT_RTC_WAKE_MIN PING_HOST NOTIFICATION_TIMEOUT WAKE_BEFORE_ALARM_MINUTES MAX_WAIT BRIGHTNESS)
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log "[ERROR] Required config variable '$var' is not set."
        exit 1
    fi
done

check_dependencies() {
    local dependencies=(logger jq gdbus grep awk sed)
    local missing=0
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log "[ERROR] '$dep' ist nicht installiert oder nicht im PATH."
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        log "[ERROR] installiere die fehlenden Abhängigkeiten und versuche es erneut."
        exit 1
    fi
}
check_dependencies

TARGET_UID=$(id -u "$TARGET_USER")
if [ ! -d "/run/user/${TARGET_UID}" ]; then
    log "[ERROR] DBus session for user $TARGET_USER not found"
    exit 1
fi

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"
XDG_RUNTIME_DIR="/run/user/${TARGET_UID}"

cleanup() {
    # release lock
    if [ -e "$LOCKFILE" ]; then
        flock -u 200
        rm -f "$LOCKFILE"
        #log "[INFO] Lockfile released and removed."
    fi
}

on_interrupt() {
    log "[ERROR] Script interrupted (SIGINT or SIGTERM)."
    turn_on_display
    log "[INFO] ===== wakeup-check.sh finished (mode: $MODE) ====="
    cleanup
    exit 6
}

on_exit() {
    # Is always called when exiting, regardless of whether error or success
    log "[INFO] ===== wakeup-check.sh finished (mode: $MODE) ====="
    cleanup
}

turn_off_display() {
    log "turn_off_display($DISPLAY_CONTROL_METHOD)"

    case "$DISPLAY_CONTROL_METHOD" in
        brightness)
            if [ -f "$BRIGHTNESS_PATH" ]; then
                CURRENT_BRIGHTNESS=$(cat "$BRIGHTNESS_PATH")

                if [ -n "$CURRENT_BRIGHTNESS" ] && [ "$CURRENT_BRIGHTNESS" -ne 0 ]; then
                    # Display ist noch an, aktuellen Wert sichern
                    if echo "$CURRENT_BRIGHTNESS" > "$BRIGHTNESS_SAVE_PATH"; then
                        log "[INFO] Saved current brightness value: $CURRENT_BRIGHTNESS"
                    else
                        log "[ERROR] Failed to save brightness to $BRIGHTNESS_SAVE_PATH"
                    fi
                else
                    # Display ist bereits aus (Helligkeit 0)
                    log "[WARN] Current brightness is 0"

                    if [ -f "$BRIGHTNESS_SAVE_PATH" ] && [ -s "$BRIGHTNESS_SAVE_PATH" ]; then
                        SAVED_BRIGHTNESS=$(cat "$BRIGHTNESS_SAVE_PATH")

                        if [ -n "$SAVED_BRIGHTNESS" ] && [ "$SAVED_BRIGHTNESS" -ne 0 ]; then
                            log "[INFO] Existing saved brightness value ($SAVED_BRIGHTNESS) is valid, no overwrite needed."
                        else
                            log "[WARN] No valid saved brightness, saving default brightness $BRIGHTNESS"
                            if [ -n "$BRIGHTNESS" ] && [ "$BRIGHTNESS" -ne 0 ]; then
                                echo "$BRIGHTNESS" > "$BRIGHTNESS_SAVE_PATH"
                                log "[INFO] Default brightness $BRIGHTNESS saved"
                            else
                                log "[ERROR] BRIGHTNESS is not set or invalid, cannot save default"
                            fi
                        fi
                    else
                        log "[WARN] Brightness save file missing or empty, saving default brightness $BRIGHTNESS"
                        if [ -n "$BRIGHTNESS" ] && [ "$BRIGHTNESS" -ne 0 ]; then
                            echo "$BRIGHTNESS" > "$BRIGHTNESS_SAVE_PATH"
                            log "[INFO] Default brightness $BRIGHTNESS saved"
                        else
                            log "[ERROR] BRIGHTNESS is not set or invalid, cannot save default"
                        fi
                    fi
                fi

                # Jetzt Display ausschalten
                if echo 0 > "$BRIGHTNESS_PATH"; then
                    log "[INFO] Brightness successfully set to 0"
                else
                    log "[ERROR] Failed to set brightness to 0"
                fi
            else
                log "[ERROR] Brightness path not found: $BRIGHTNESS_PATH"
            fi
            ;;
        
        screensaver)
            if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
                if sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                    gdbus call --session \
                    --dest org.gnome.ScreenSaver \
                    --object-path /org/gnome/ScreenSaver \
                    --method org.gnome.ScreenSaver.SetActive true >/dev/null; then
                    log "[INFO] Display locked via GNOME ScreenSaver"
                else
                    log "[ERROR] Failed to lock display via GNOME ScreenSaver"
                fi
            else
                log "[ERROR] DBUS_SESSION_BUS_ADDRESS is not set — cannot lock display"
            fi
            ;;
        
        *)
            log "[ERROR] Unknown DISPLAY_CONTROL_METHOD: $DISPLAY_CONTROL_METHOD — check config file"
            ;;
    esac
}

turn_on_display() {
    log "turn_on_display($DISPLAY_CONTROL_METHOD)"

    case "$DISPLAY_CONTROL_METHOD" in
        brightness)
            # Set a default brightness if no valid value is found
            DEFAULT_BRIGHTNESS=50

            if [ -f "$BRIGHTNESS_SAVE_PATH" ] && [ -s "$BRIGHTNESS_SAVE_PATH" ]; then
                SAVED_BRIGHTNESS=$(cat "$BRIGHTNESS_SAVE_PATH")

                if [ -n "$SAVED_BRIGHTNESS" ] && [ "$SAVED_BRIGHTNESS" -ne 0 ]; then
                    BRIGHTNESS="$SAVED_BRIGHTNESS"
                    log "[INFO] Restored saved brightness value: $BRIGHTNESS"
                else
                    BRIGHTNESS=$DEFAULT_BRIGHTNESS
                    log "[WARN] Saved brightness invalid (empty or 0), setting default brightness to $BRIGHTNESS"
                fi
            else
                BRIGHTNESS=$DEFAULT_BRIGHTNESS
                log "[ERROR] No saved brightness value found or file empty, setting brightness to $BRIGHTNESS"
            fi

            if echo "$BRIGHTNESS" > "$BRIGHTNESS_PATH"; then
                log "[INFO] Brightness set to $BRIGHTNESS"
            else
                log "[ERROR] Failed to set brightness to $BRIGHTNESS"
            fi
            ;;
        
        screensaver)
            if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
                if sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                    gdbus call --session \
                    --dest org.gnome.ScreenSaver \
                    --object-path /org/gnome/ScreenSaver \
                    --method org.gnome.ScreenSaver.SetActive false >/dev/null; then
                    log "[INFO] Display unlock requested via GNOME ScreenSaver"
                else
                    log "[ERROR] Failed to unlock display via GNOME ScreenSaver"
                fi
            else
                log "[ERROR] DBUS_SESSION_BUS_ADDRESS is not set — cannot unlock display"
            fi
            ;;
        
        *)
            log "[ERROR] Unknown DISPLAY_CONTROL_METHOD: $DISPLAY_CONTROL_METHOD — check config file"
            ;;
    esac
}

use_fbcli() {
    if [ "$NOTIFICATION_USE_FBCLI" == "true" ]; then
        if command -v fbcli >/dev/null 2>&1; then
            log "[INFO] Using fbcli for notification"
            sudo -u "$TARGET_USER" fbcli -E notification-missed-generic
            sudo -u "$TARGET_USER" fbcli -E message-new-instant
        else
            log "[ERROR] fbcli not found, skipping fbcli notifications"
        fi
    fi
}

handle_notification_actions() {
    if [[ "$NOTIFICATION_TURN_ON_DISPLAY" == "true" ]]; then
        log "[INFO] Turning display on due to notification..."
        turn_on_display
    fi

    if [[ "$NOTIFICATION_USE_FBCLI" == "true" ]]; then
        log "[INFO] Calling fbcli due to notification..."
        use_fbcli
    fi
}

is_quiet_hours() {
    local now=$(date +%s)
    local today=$(date +%Y-%m-%d)
    local start_ts=$(date -d "$today $QUIET_HOURS_START" +%s)
    local end_ts

    # Numerical comparison for detection “over midnight”
    local start_hms=$(date -d "$QUIET_HOURS_START" +%s)
    local end_hms=$(date -d "$QUIET_HOURS_END" +%s)

    if (( end_hms > start_hms )); then
        end_ts=$(date -d "$today $QUIET_HOURS_END" +%s)
    else
        end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    #log "Current time: $(date -d @$now)"
    #log "Quiet hours: $(date -d @$start_ts) - $(date -d @$end_ts)"

    if (( now >= start_ts && now < end_ts )); then
        #log "Currently in quiet hours."
        return 0
    else
        #log "Not in quiet hours."
        return 1
    fi
}

is_rtc_wakeup() {
    if [ ! -f "$WAKE_TIMESTAMP_FILE" ]; then
        log "[ERROR] No wake timestamp file found"
        return 1
    fi

    local timestamp_file_ts rtc_now diff
    rtc_now=$(date +%s)
    timestamp_file_ts=$(cat "$WAKE_TIMESTAMP_FILE")

    if ! [[ "$timestamp_file_ts" =~ ^[0-9]+$ ]]; then
        log "[ERROR] Invalid timestamp in file: $WAKE_TIMESTAMP_FILE"
        return 1
    fi

    diff=$((rtc_now - timestamp_file_ts))

    if (( diff >= 0 && diff <= RTC_WAKE_WINDOW_SECONDS )); then
        log "[INFO] RTC wake confirmed now: $(date -d @$rtc_now), timestamp: $(date -d @$timestamp_file_ts), diff: $diff"
        return 0
    else
        log "[INFO] Not an RTC wake: $(date -d @$rtc_now), timestamp: $(date -d @$timestamp_file_ts), diff: $diff"
        return 1
    fi
}

set_rtc_wakeup() {
    local now=$(date +%s)
    local today=$(date +%Y-%m-%d)
    local start_ts end_ts quiet_end_ts
    local next_alarm_ts adjusted_wake_ts wake_ts

    #log "Setting RTC Wakeup Current time: $(date -d @$now +'%Y-%m-%d %H:%M:%S')"

    start_ts=$(date -d "$today $QUIET_HOURS_START" +%s)

    if [[ "$QUIET_HOURS_END" > "$QUIET_HOURS_START" ]]; then
        end_ts=$(date -d "$today $QUIET_HOURS_END" +%s)
    else
        end_ts=$(date -d "tomorrow $QUIET_HOURS_END" +%s)
    fi

    quiet_end_ts=$end_ts
    log "[INFO] Quiet hours: $(date -d @$start_ts +'%Y-%m-%d %H:%M:%S') - $(date -d @$quiet_end_ts +'%Y-%m-%d %H:%M:%S')"

    next_alarm_ts=$(get_next_alarm_time)
    if [[ -n "$next_alarm_ts" && "$next_alarm_ts" =~ ^[0-9]+$ ]]; then
        log "[INFO] Next alarm at: $(date -d @$next_alarm_ts +'%Y-%m-%d %H:%M:%S')"
    else
        [INFO] log "No valid alarm found - skipping alarm adjustment"
        next_alarm_ts=""
    fi

    if is_quiet_hours; then
        #log "[INFO] Currently in quiet hours"
        wake_ts=$quiet_end_ts
        log "[INFO] In quiet hours, setting wake time to end of quiet hours $(date -d @$QUIET_HOURS_START) - $(date -d @$QUIET_HOURS_END) " > ": $(date -d @$wake_ts)"
    else
        wake_ts=$(( now + (NEXT_RTC_WAKE_MIN * 60) ))
        log "[INFO] Not in quiet hours - setting default RTC wake in ${NEXT_RTC_WAKE_MIN} minutes: $(date -d @$wake_ts)"
    fi

    if [[ -n "$next_alarm_ts" && "$next_alarm_ts" -gt "$now" && "$next_alarm_ts" -lt "$wake_ts" ]]; then
        adjusted_wake_ts=$(( next_alarm_ts - (WAKE_BEFORE_ALARM_MINUTES * 60) ))
        log "[INFO] Alarm is earlier than current wake time - adjusting RTC wake to: $(date -d @$adjusted_wake_ts)"
        wake_ts=$adjusted_wake_ts
    fi

    
    if ! echo "$wake_ts" | grep -q '^[0-9]\+$'; then
        log "[ERROR] Invalid wake_ts: $wake_ts"
        exit 1
    fi
    
    if ! echo "$wake_ts" > "$WAKE_TIMESTAMP_FILE"; then
        log "[ERROR] Failed to write timestamp file: $WAKE_TIMESTAMP_FILE"
        exit 1
    fi

    if ! echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || ! echo "$wake_ts" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null; then
        log "[ERROR] Failed to set RTC wakealarm"
        exit 1
    fi

    #log "RTC wakealarm set to: $(date -d @$wake_ts)"
    local tsf_actual=$(cat "$WAKE_TIMESTAMP_FILE")
    local rtc_actual=$(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null)
    
    if [[ "$rtc_actual" == "$tsf_actual" ]]; then
        #log "RTC wakealarm and saved timestamp match"
        log "[INFO] Will wake system at: $(date -d @$wake_ts) due to: $(is_quiet_hours && echo 'end of quiet hours' || echo 'default timing or alarm adjustment')"
    else
        log "[ERROR] RTC wakealarm mismatch - actual: $rtc_actual, timestampfile: $tsf_actual"
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

check_alarm_within_minutes() {
    local next_alarm_ts
    next_alarm_ts=$(get_next_alarm_time)

    if [[ -z "$next_alarm_ts" || ! "$next_alarm_ts" =~ ^[0-9]+$ ]]; then
        log "[INFO] No valid next alarm time found"
        return 1
    fi

    local now=$(date +%s)
    local diff=$(( next_alarm_ts - now ))

    log "[INFO] Next alarm in $diff seconds (limit: $(( WAKE_BEFORE_ALARM_MINUTES * 60 )) seconds)"

    if (( diff >= 0 && diff <= WAKE_BEFORE_ALARM_MINUTES * 60 )); then
        log "[INFO] Alarm within next $WAKE_BEFORE_ALARM_MINUTES minutes detected"
        return 0
    fi

    return 1
}

wait_for_internet() {
    log "[INFO] Waiting up to $MAX_WAIT seconds for internet..."
    local start_time=$(date +%s)

    while true; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))

        if (( elapsed >= MAX_WAIT )); then
            #log "[WARNING] Internet wait timeout after $MAX_WAIT seconds"
            return 1
        fi

        if status=$(nmcli networking connectivity 2>/dev/null) && [[ "$status" == "full" ]]; then
            #log "Internet connection is available (nmcli)"
            return 0
        fi

        if ping -q -c 1 -W 2 "$PING_HOST" >/dev/null 2>&1; then
            #log "Internet connection is available (ping to $PING_HOST)"
            return 0
        fi
        sleep 1 # pause till next check
    done
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
    log "[INFO] Monitoring notifications for $timeout_duration seconds..."

    local found_notification=0

    while IFS= read -r line; do
        if echo "$line" | grep -q '"member":"Notify"'; then
            found_notification=1

            app_name=$(echo "$line" | jq -r '.payload.data[0]' 2>/dev/null)
            desktop_entry=$(echo "$line" | jq -r '.payload.data[6]["desktop-entry"].data // empty' 2>/dev/null)

            if [[ -z "$desktop_entry" ]]; then
                check_entry="$app_name"
            else
                check_entry=$(get_app_name_from_desktop_entry "$desktop_entry")
            fi

            if is_whitelisted "$check_entry"; then
                log "[INFO] Allowed notification from: $check_entry"
                return 0
            else
                log "[INFO] Disallowed notification from: $check_entry"
            fi
        fi
    done < <(
        timeout "$timeout_duration" \
            sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            busctl --user monitor org.freedesktop.Notifications --json=short 2>/dev/null || true
    )

    if [ "$found_notification" -eq 1 ]; then
        #log "notificcation"
        return 1  # Notifications kamen, aber keine erlaubte
    else
        #log "timeout"
        return 124  # Keine Notification kam
    fi
}

# ===== TRAPS =====
trap on_interrupt INT TERM
trap on_exit EXIT

# ---------- MAIN ----------
MODE="$1"

if [[ -z "$MODE" ]]; then
    log "[ERROR] No mode specified (expected 'pre' or 'post')"
    exit 1
fi
if [[ "$MODE" != "pre" && "$MODE" != "post" ]]; then
    log "[ERROR] Invalid mode: $MODE (expected 'pre' or 'post')"
    exit 1
fi

if [[ "$MODE" == "pre" ]]; then
    log "[INFO] ===== wakeup-check.sh started (mode: $MODE) ====="
    turn_off_display
    set_rtc_wakeup
fi

if [[ "$MODE" == "post" ]]; then
    log "[INFO] ===== wakeup-check.sh started (mode: $MODE) ====="
    turn_off_display
    if is_rtc_wakeup; then
        log "[INFO] RTC wake detected."

        if check_alarm_within_minutes; then
            log "[INFO] Alarm is coming up soon - staying awake."
            turn_on_display
        elif is_quiet_hours; then
            log "[INFO] Currently in quiet hours - suspending again."
            systemctl suspend
        else
            if wait_for_internet; then
                log "[INFO] Internet connection detected"
                # Aufruf der monitor_notifications-Funktion
                monitor_notifications
                result=$?
                # Überprüfen der Rückgabe und Ausgabe von entsprechenden Meldungen
                if [[ $result -eq 0 ]]; then
                    log "[INFO] Notification monitoring completed successfully, allowed notification received. -> notify"
                    handle_notification_actions
                elif [[ $result -eq 124 ]]; then
                    log "[INFO] Timeout reached without receiving notifications. -> sleep"
                    systemctl suspend
                elif [[ $result -eq 1 ]]; then
                    log "[INFO] Notification monitoring returned 1 - disallowed notification or error. -> sleep"
                    systemctl suspend
                else
                    log "[ERROR] Unexpected error occurred in notification monitoring. Exiting with code $result."
                    turn_on_display
                fi
            else
                log "[WARNING] No internet connection detected - suspending"
                systemctl suspend
            fi
        fi
    else
        log "[INFO] Not an RTC wake. -> turn on display"
        turn_on_display
    fi
fi

exit 0

