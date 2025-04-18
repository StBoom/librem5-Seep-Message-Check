Complete Summary of the Script Functions:

    RTC Wake Functionality:

        set_rtc_wakeup:
        Schedules the next RTC wake-up by setting the RTC alarm to go off in a specified interval (NEXT_RTC_WAKE_MIN), which is read from the configuration file. It writes the wake time to the WAKE_TIMESTAMP_FILE.

        is_rtc_wakeup:
        Checks if the current wake-up is from an RTC alarm. It compares the time stored in WAKE_TIMESTAMP_FILE with the current time and ensures that the time difference is within a valid RTC wake-up window (RTC_WAKE_WINDOW_SECONDS).

    Display Control:

        turn_off_display:
        Turns off the display using the gdbus method for GNOME ScreenSaver, called with the SetActive method set to true.

        turn_on_display:
        Turns on the display by calling the SetActive method with false via gdbus.

    Notification Handling:

        monitor_notifications:
        Listens for incoming notifications using dbus-monitor. The script checks for notifications that come from relevant applications (based on NOTIFICATION_MODE). If the notification is deemed relevant (in "whitelist" mode or "all" mode), it can trigger the display to turn on and optionally use fbcli to notify the user. It checks for a specific notification timeout (NOTIFICATION_TIMEOUT).

        use_fbcli:
        If enabled in the config (NOTIFICATION_USE_FBCLI="true"), this function uses fbcli to trigger a visual notification.

    Internet Connectivity Check:

        wait_for_internet:
        This function attempts to wait for an internet connection by checking the system's network connectivity status (nmcli networking connectivity). If a connection is not found, it falls back to using ping to verify whether the system can reach the configured PING_HOST (1.1.1.1 in this case). It will try for up to MAX_WAIT seconds as defined in the configuration.

    Quiet Hours Check:

        is_quiet_hours:
        This function checks if the current time falls within the defined quiet hours. The quiet hours start and end times are configurable via the QUIET_HOURS_START and QUIET_HOURS_END parameters. If the current time is within the quiet hours, certain actions (such as waking up from suspend) can be suppressed.

    Logging:

        log:
        This is a general-purpose logging function that logs messages to a file (LOGFILE) with timestamps. It is used throughout the script to track actions and events.

    Main Logic (Mode Handling):

        Pre Mode (pre):
        In the pre mode, the script schedules an RTC wake-up time by calling set_rtc_wakeup and then suspends the system (systemctl suspend).

        Post Mode (post):
        In the post mode, the script checks if the system was awakened by the RTC alarm (is_rtc_wakeup). If true, it checks if the current time is within quiet hours (is_quiet_hours). If not in quiet hours, it waits for internet connectivity (wait_for_internet). If the internet is available, it begins monitoring notifications (monitor_notifications). If relevant notifications are found, the system stays awake; otherwise, it suspends again. If no internet is detected, the system suspends again without checking notifications.

Files and Parameters to be Set:

    Configuration File /etc/wakeup-check.conf:
    Contains variables like TARGET_USER, WAKE_TIMESTAMP_FILE, NEXT_RTC_WAKE_MIN, RTC_WAKE_WINDOW_SECONDS, MAX_WAIT, etc.

    Main Script File wakeup-check.sh:
    The actual script that executes the logic for checking RTC wake-up, handling notifications, internet connectivity, quiet hours, and system suspend.

    Log File:
    The log file (e.g., /var/log/wakeup-check.log) will store the timestamped logs of all actions taken by the script.
