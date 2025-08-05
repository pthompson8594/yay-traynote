#!/bin/bash
# Fix service without requiring sudo (user-only service)

echo "Fixing systemd service configuration for Wayland (user-only)..."

# Stop and disable old service
systemctl --user stop yay-traynote.service 2>/dev/null || true
systemctl --user disable yay-traynote.service 2>/dev/null || true

# Create user service directory
mkdir -p ~/.config/systemd/user

# Install service file to user directory instead
echo "Installing service file to user directory..."
cp yay-traynote.service ~/.config/systemd/user/yay-traynote.service

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable yay-traynote.service

echo "Waiting for desktop session..."
sleep 3

echo "Starting service..."
systemctl --user start yay-traynote.service

echo
echo "Service status:"
systemctl --user status yay-traynote.service --no-pager -l

echo
echo "Display server debug info:"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
echo "DISPLAY: ${DISPLAY:-not set}"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
echo
echo "If still failing, try running manually:"
echo "  python3 $(pwd)/yay-traynote.py"
