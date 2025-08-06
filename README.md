# YAY Update Notifier

A lightweight system tray application that monitors for Arch Linux package updates using `yay` and shows desktop non intrusive notifications when updates are available.

## Features

- **Icon Flashing**: System tray icon flashes slowly when updates are available
- **System Tray Integration**: Runs quietly in the background
- **Configurable Check Intervals**: 30 minutes to daily
- **Built-in Terminal**: Run yay updates directly from the tray menu
- **Auto-refresh**: Automatically checks for updates after running yay
- **Single Instance**: Prevents multiple copies from running
- **Minimal Resource Usage**: No GUI, just visual notifications
- **Passwordless Sync**: Syncs package database without password prompts
- **Graceful Exit**: Proper Ctrl+C handling for clean shutdown

## Installation

### Quick Install (Recommended)

1. Run the installation script:
   ```bash
   ./install.sh
   ```

This will install the notifier as a systemd user service and set up all dependencies.

### Manual Installation

1. Ensure you have the required dependencies:
   ```bash
   sudo pacman -S python-pyqt6
   ```

2. Setup passwordless sudo for package database syncing:
   ```bash
   ./setup-sudo.sh
   ```

3. Make the script executable:
   ```bash
   chmod +x yay-traynote.py
   ```

4. Run the notifier:
   ```bash
   ./yay-traynote.py
   ```

### Package Installation

1. Build the package:
   ```bash
   ./build-package.sh
   ```

2. Install with pacman (if building PKGBUILD):
   ```bash
   makepkg -si
   ```

## Usage

- The application runs as a system tray icon
- Right-click the tray icon to access settings
- Icon flashes slowly (3-second cycle) when updates are available
- Icon flashes quickly when checking for updates
- Use "Run YAY Updates" to open terminal and install updates
- Updates are automatically checked after running yay
- Configure check intervals from 30 minutes to daily
- Use "Clear Update Alert" to stop flashing manually
- Exit cleanly with Ctrl+C when running from terminal

## Configuration

Settings are automatically saved to `~/.config/yay-traynote/settings.json`:

- **Check Interval**: How often to check for updates
- **Last Check**: Timestamp of the last update check

## System Tray Menu

- **Check for Updates Now**: Manually trigger an update check
- **Run YAY Updates**: Open terminal and run yay, auto-checks when finished
- **Settings**:
  - **Check Interval**: Set how often to check (30 min - daily)
  - **Clear Update Alert**: Stop flashing icon manually
- **About**: Application information

## Service Management

When installed as a systemd service:

```bash
# Start service
systemctl --user start yay-traynote.service

# Stop service
systemctl --user stop yay-traynote.service

# Enable auto-start
systemctl --user enable yay-traynote.service

# Check status
systemctl --user status yay-traynote.service

# View logs
journalctl --user -u yay-traynote.service -f
```

## Requirements

- Arch Linux
- Python 3.6+
- PyQt6 (`python-pyqt6`)
- `yay` (AUR helper)
- System tray support
- Terminal emulator (gnome-terminal, konsole, or xterm)


