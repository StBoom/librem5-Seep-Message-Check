# Wakeup Check Configuration and Script

This project provides a system that checks whether the computer has woken up from suspend or hibernation, and handles certain tasks based on the wake-up event. These tasks include displaying notifications, adjusting the RTC (Real-Time Clock) wake-up, and ensuring the system is ready for further use.

## Files Overview

### 1. **wakeup-check.sh** (Script)

This script is responsible for performing the wake-up check after the system wakes up from suspend or hibernation. It handles tasks such as setting the RTC wake-up time, managing notifications, and controlling the display.

Key Functions:
- **Turning off the display**: Ensures the display is turned off after wake-up to prevent it from remaining active unnecessarily.
- **Handling notifications**: Monitors incoming notifications from whitelisted applications and manages how they are displayed or handled.
- **Setting RTC wake-up time**: Determines when the system should wake up next based on quiet hours, the next alarm, or RTC wake time.
- **Waiting for internet connection**: Waits for the internet connection to be available before proceeding with further actions.

### 2. **wakeup-check.conf** (Configuration File)

This is the configuration file for the script `wakeup-check.sh`. It contains various settings such as:
- **Log file path**: Defines where logs are saved.
- **User settings**: Specifies the user under which the script should run and the necessary UID for DBus.
- **Internet connection settings**: Configures the server to ping to verify the internet connection.
- **Notification settings**: Defines how notifications should behave, including notification timeouts and display preferences.
- **RTC wake-up settings**: Configures wake-up time before the alarm, the window of time for RTC wake detection, and other alarm-related settings.
- **Quiet hours settings**: Configures quiet hours during which notifications or certain actions might be suppressed.
- **App whitelist**: Specifies which applications' notifications should be processed.

### 3. **wakeup-check-pre.service** (Systemd Pre-Suspend Unit)

This **systemd service unit** ensures that the `wakeup-check.sh` script is executed before the system enters suspend mode. It allows tasks such as setting the RTC wake-up time to be handled before sleep occurs.

Key Points:
- The service runs in **oneshot** mode, meaning it only executes once.
- It is triggered before the `sleep.target` to ensure tasks are completed before suspension.
- The unit can be enabled to automatically run on suspend, or manually triggered.

### 4. **wakeup-check-post.service** (Systemd Post-Suspend Unit)

This **systemd service unit** ensures that the `wakeup-check.sh` script is executed after the system wakes up from suspend mode. It performs tasks such as checking for RTC wake-up, managing notifications, and verifying the internet connection.

Key Points:
- The service runs in **oneshot** mode, meaning it only executes once.
- It is triggered after the `suspend.target`, meaning it only runs after the system wakes up.
- The unit can be enabled to automatically run after wake-up, or manually triggered.


## installation script


```bash
git clone https://github.com/StBoom/librem5-Seep-Message-Check.git
sudo bash install.sh
```

## Manual installation

### 1. Copy Files to Appropriate Locations

To install the `wakeup-check` system, copy the files to their respective locations:

- **Script**: Copy `wakeup-check.sh` to `/usr/local/bin/`.
- **Configuration**: Copy `wakeup-check.conf` to `/etc/`.
- **Systemd Unit Files**: Copy `wakeup-check-pre.service` and `wakeup-check-post.service` to `/etc/systemd/system/`.

### 2. Set Correct Permissions for the Script

Ensure that the script has the correct permissions to be executed:

```bash
sudo chmod +x /usr/local/bin/wakeup-check.sh
```

### 3. Set Correct Permissions for the Log and Timestamp Files

Make sure that the log file and timestamp file have the correct permissions for the script to write to:

```bash
sudo touch /var/log/wakeup-check.log
sudo chmod 666 /var/log/wakeup-check.log

sudo mkdir /var/lib/wakeup-check
sudo touch /var/lib/wakeup-check/last_wake_timestamp
sudo chmod 666 /var/lib/wakeup-check/last_wake_timestamp
```

### 4. Reload Systemd

Once the unit files are in place, reload systemd to recognize the new services:

```bash
sudo systemctl daemon-reload
```

### 5. Enable and Start the Services

Enable and start the services to ensure they automatically run on suspend and wake events:

```bash
sudo systemctl enable wakeup-check-pre.service
sudo systemctl enable wakeup-check-post.service
sudo systemctl start wakeup-check-pre.service
sudo systemctl start wakeup-check-post.service
```

### 6. Customize Configuration

Edit the wakeup-check.conf file to adjust the settings to your preference. The key configuration options you can modify are:

    TARGET_USER: Set this to your actual username for user-specific settings.

    NOTIFICATION_MODE: Defines which notifications are handled. You can set it to all or define a specific whitelist of applications.

    RTC wake-up time and window: Configure how long the system should wait before waking up and the window of time for RTC wake detection.

    Quiet hours: Customize the hours during which the system suppresses notifications.

After editing the configuration file, save the changes.
### Explanation

    wakeup-check.sh: This script handles the wake-up checks. It checks if the wake-up event was RTC-based, sets the RTC alarm, monitors notifications, and turns the display on or off based on the settings in the configuration file.

    wakeup-check.conf: The configuration file for the script, where various settings like notification preferences, alarm times, and RTC wake settings are defined.

    Systemd Unit Files: The two unit files manage the execution of the script during pre-suspend and post-suspend events. These files make sure the script is triggered at the correct moments (before the system suspends and after it wakes up).

#### Pre-Suspend (wakeup-check-pre.service)

This unit is triggered before the system enters suspend mode. It executes the wakeup-check.sh pre command, ensuring that the RTC wake-up time is set and any necessary tasks are performed before the system goes into suspend.
#### Post-Suspend (wakeup-check-post.service)

This unit is triggered after the system has woken up from suspend mode. It executes the wakeup-check.sh post command, checking for RTC wake events, managing notifications, and verifying that the system is ready to proceed (including internet connectivity).
### Troubleshooting

If you experience issues with the system, the logs can help you diagnose the problem:

```bash
tail -f /var/log/wakeup-check.log
```

This will show real-time logs from the script. Check for any error messages related to file permissions, RTC wake-up, or systemd unit failures.
