#!/bin/bash
# Quick fix for the systemd service

echo "Fixing systemd service configuration for Wayland..."

# Stop and disable old service
systemctl --user stop yay-traynote.service 2>/dev/null || true
systemctl --user disable yay-traynote.service 2>/dev/null || true

# Install fixed service file
echo "Installing fixed service file..."
sudo cp yay-traynote.service /etc/systemd/user/yay-traynote.service

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable yay-traynote.service

# Wait a moment for desktop session
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
echo "  /usr/bin/yay-traynote"
