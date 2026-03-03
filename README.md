# Thermal Guardian

A macOS launchd user agent that protects your MacBook Pro from thermal damage
when running in clamshell mode with [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)
preventing sleep.

## Problem

When using Amphetamine to keep a MacBook Pro awake with the lid closed (e.g.,
connected to an external display), heat from the CPU and battery gets trapped
between the display and keyboard. If battery temperature reaches dangerous
levels, this can accelerate battery degradation and potentially damage the
display panel adhesives.

## Solution

Thermal Guardian runs every 60 seconds and checks three conditions:

1. **Battery temperature** exceeds a configurable threshold (default: 50°C)
2. **Lid is closed** (clamshell mode)
3. **Amphetamine has an active session** (preventing sleep)

When all three conditions are true simultaneously, it:

1. Sends a macOS notification (visible on next wake)
2. Ends the Amphetamine session
3. Waits 3 seconds for cleanup
4. Forces the system to sleep

This script **never starts** Amphetamine or any sessions — it only monitors and
kills when dangerous conditions are detected.

## Requirements

- macOS (tested on macOS Sequoia / Apple Silicon M3 Pro)
- [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) installed
- No sudo required

## Installation

```bash
git clone https://github.com/GraysonCAdams/thermal-guardian.git ~/Repos/thermal-guardian
cd ~/Repos/thermal-guardian
./install.sh
```

## Uninstallation

```bash
cd ~/Repos/thermal-guardian
./uninstall.sh
```

## Configuration

Edit the variables at the top of `thermal-guardian.sh`:

| Variable | Default | Description |
|---|---|---|
| `TEMP_THRESHOLD_C` | `50` | Battery temperature in °C that triggers protection |
| `LOG_MAX_BYTES` | `1048576` | Max log file size before rotation (1 MB) |
| `SLEEP_AFTER_END_SESSION` | `3` | Seconds to wait after ending Amphetamine session |

After editing, changes take effect on the next 60-second cycle (no reload needed
since the script is re-executed each time by launchd).

## Monitoring

```bash
# Watch live logs
tail -f ~/Library/Logs/ThermalGuardian.log

# Check if the agent is loaded
launchctl list | grep thermal-guardian

# Check current battery temperature
ioreg -r -n AppleSmartBattery -d 1 | grep '"Temperature"'

# Manual test run
./thermal-guardian.sh
```

## Log Files

| File | Contents |
|---|---|
| `~/Library/Logs/ThermalGuardian.log` | Structured application logs (auto-rotated at 1 MB) |
| `~/Library/Logs/ThermalGuardian-stdout.log` | launchd stdout capture |
| `~/Library/Logs/ThermalGuardian-stderr.log` | launchd stderr capture |

## How It Works

The script reads battery temperature from `ioreg` (AppleSmartBattery), which
reports in decikelvin. For example, `3049` = 304.9 K = 31.75°C. The threshold
comparison is done in decikelvin using integer arithmetic to avoid floating-point
issues in bash.

Amphetamine is checked via `pgrep -x Amphetamine` before any AppleScript is sent,
ensuring the app is never launched just to query it.

## Why 50°C?

- Apple Silicon chips safely run 80–100°C under load, but **battery cells** are
  the concern here — not the CPU
- Li-ion battery degradation accelerates above 45°C and becomes dangerous above 55°C
- With the lid closed, the battery's heat has nowhere to go — normally the display
  acts as a heatsink
- 50°C gives a meaningful margin above normal clamshell temps (~35–42°C) while
  triggering well before the danger zone for battery chemistry
- This avoids false positives during normal heavy workloads while catching the
  genuinely dangerous trapped-heat scenario

## License

MIT
