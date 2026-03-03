#!/bin/bash
# thermal-guardian.sh - Thermal protection for clamshell MacBook Pro
# Ends Amphetamine session and forces sleep when battery temp is dangerously high
# with the lid closed.

set -euo pipefail

# ──────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────
TEMP_THRESHOLD_C=50          # Celsius - trigger threshold
LOG_FILE="$HOME/Library/Logs/ThermalGuardian.log"
LOG_MAX_BYTES=1048576        # 1 MB max log size
SLEEP_AFTER_END_SESSION=3    # seconds to wait after ending Amphetamine session

# ──────────────────────────────────────────────────────
# Derived constants (do not edit)
# ──────────────────────────────────────────────────────
# Convert threshold to decikelvin for integer comparison
# Formula: decikelvin = (celsius + 273.15) * 10
# Using integer math: (C * 10) + 2732 (rounding 2731.5 up for safety)
TEMP_THRESHOLD_DK=$(( (TEMP_THRESHOLD_C * 10) + 2732 ))

# ──────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────
log() {
    local level="$1"
    shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $*" >> "$LOG_FILE"
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if (( size > LOG_MAX_BYTES )); then
            local tmp
            tmp=$(tail -100 "$LOG_FILE")
            echo "$tmp" > "$LOG_FILE"
            log "INFO" "Log rotated (was ${size} bytes)"
        fi
    fi
}

# ──────────────────────────────────────────────────────
# Sensor Reads
# ──────────────────────────────────────────────────────
get_battery_temp_dk() {
    # Returns battery temperature in decikelvin (integer)
    # e.g., 3049 means 304.9 K = 31.75°C
    ioreg -r -n AppleSmartBattery -d 1 | grep '"Temperature"' | awk '{print $NF}'
}

dk_to_celsius() {
    # Convert decikelvin integer to Celsius string with 2 decimal places
    local dk="$1"
    awk -v dk="$dk" 'BEGIN { printf "%.2f", (dk / 10) - 273.15 }'
}

is_clamshell_closed() {
    # Returns 0 (true) if lid is closed, 1 (false) if open
    local state
    state=$(ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState | awk '{print $NF}')
    [[ "$state" == "Yes" ]]
}

is_amphetamine_running() {
    # Returns 0 if Amphetamine process is running, 1 otherwise
    pgrep -x Amphetamine > /dev/null 2>&1
}

is_amphetamine_session_active() {
    # Returns 0 if an Amphetamine session is active, 1 otherwise
    # IMPORTANT: Only call this if is_amphetamine_running returns true,
    # so we never accidentally launch the app.
    local result
    result=$(osascript -e 'tell application "Amphetamine" to return session is active' 2>/dev/null)
    [[ "$result" == "true" ]]
}

# ──────────────────────────────────────────────────────
# Actions (read-only checks + kill only, never starts)
# ──────────────────────────────────────────────────────
send_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Sosumi\"" 2>/dev/null || true
}

end_amphetamine_session() {
    osascript -e 'tell application "Amphetamine" to end session' 2>/dev/null
}

force_sleep() {
    osascript -e 'tell application "System Events" to sleep' 2>/dev/null
}

# ──────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    rotate_log

    # 1. Read battery temperature
    local temp_dk
    temp_dk=$(get_battery_temp_dk)
    if [[ -z "$temp_dk" ]]; then
        log "ERROR" "Could not read battery temperature"
        exit 1
    fi

    local temp_c
    temp_c=$(dk_to_celsius "$temp_dk")

    # 2. Check clamshell state
    local lid_closed=false
    if is_clamshell_closed; then
        lid_closed=true
    fi

    # 3. Check Amphetamine status (pgrep first - never launches the app)
    local amph_active=false
    if is_amphetamine_running; then
        if is_amphetamine_session_active; then
            amph_active=true
        fi
    fi

    # 4. Evaluate temperature threshold
    local temp_over=false
    if (( temp_dk >= TEMP_THRESHOLD_DK )); then
        temp_over=true
    fi

    log "DEBUG" "temp=${temp_c}°C (${temp_dk}dk) lid_closed=${lid_closed} amph_active=${amph_active} threshold=${TEMP_THRESHOLD_C}°C (${TEMP_THRESHOLD_DK}dk)"

    # 5. Act if ALL three conditions are met
    if [[ "$temp_over" == "true" && "$lid_closed" == "true" && "$amph_active" == "true" ]]; then
        log "WARN" "THERMAL ALERT: Battery at ${temp_c}°C (threshold: ${TEMP_THRESHOLD_C}°C), lid closed, Amphetamine active"
        log "WARN" "Ending Amphetamine session and forcing sleep to protect hardware"

        send_notification "Thermal Guardian" "Battery at ${temp_c}°C with lid closed. Ending Amphetamine session and sleeping."

        end_amphetamine_session
        log "INFO" "Amphetamine session ended"

        sleep "$SLEEP_AFTER_END_SESSION"

        log "INFO" "Forcing system sleep"
        force_sleep

        log "INFO" "Sleep command issued"
    fi
}

main "$@"
