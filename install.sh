#!/bin/bash
"""
YAY Update Notifier Installation Script
Installs the notifier as a system service
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/bin"
SERVICE_DIR="/etc/systemd/user"
ICON_DIR="/usr/share/pixmaps"
SERVICE_NAME="yay-traynote"

# Get current user
CURRENT_USER=$(whoami)
USER_ID=$(id -u)

echo -e "${BLUE}YAY Update Notifier Installation${NC}"
echo "=================================="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root!${NC}"
    echo "Run as your regular user. The script will ask for sudo when needed."
    exit 1
fi

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
missing_deps=()

if ! command -v python3 &> /dev/null; then
    missing_deps+=("python3")
fi

if ! python3 -c "import PyQt6" &> /dev/null; then
    missing_deps+=("python-pyqt6")
fi

if ! command -v yay &> /dev/null; then
    missing_deps+=("yay")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
    echo "Install them with: sudo pacman -S ${missing_deps[*]}"
    exit 1
fi

echo -e "${GREEN}✓ All dependencies found${NC}"
echo

# Stop existing service if running
echo -e "${YELLOW}Stopping existing service (if running)...${NC}"
systemctl --user stop $SERVICE_NAME.service 2>/dev/null || true
systemctl --user disable $SERVICE_NAME.service 2>/dev/null || true

# Install files
echo -e "${YELLOW}Installing files...${NC}"

# Install main script
echo "Installing $SERVICE_NAME to $INSTALL_DIR/"
sudo cp yay-traynote.py "$INSTALL_DIR/$SERVICE_NAME"
sudo chmod +x "$INSTALL_DIR/$SERVICE_NAME"

# Install icon
echo "Installing icon to $ICON_DIR/"
sudo cp yay-traynote-icon.svg "$ICON_DIR/yay-traynote-icon.svg"

# Install service file
echo "Installing systemd service to $SERVICE_DIR/"
sudo mkdir -p "$SERVICE_DIR"
sudo cp yay-traynote.service "$SERVICE_DIR/$SERVICE_NAME.service"

echo -e "${GREEN}✓ Files installed${NC}"
echo

# Setup passwordless sudo
echo -e "${YELLOW}Setting up passwordless sudo for package sync...${NC}"
if [ -f "setup-sudo.sh" ]; then
    ./setup-sudo.sh
else
    echo -e "${RED}Warning: setup-sudo.sh not found. You'll need to manually setup passwordless sudo for 'yay -Sy'${NC}"
fi

echo

# Reload systemd and enable service
echo -e "${YELLOW}Configuring systemd service...${NC}"
systemctl --user daemon-reload
systemctl --user enable $SERVICE_NAME.service

echo -e "${GREEN}✓ Service enabled${NC}"
echo

# Start service
echo -e "${YELLOW}Starting service...${NC}"

# Wait for desktop session to be fully loaded
echo "Waiting for desktop session..."
sleep 3

if systemctl --user start $SERVICE_NAME.service; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start service${NC}"
    echo "Check logs with: journalctl --user -u $SERVICE_NAME.service"
    
    # Show helpful debug info for Wayland/X11 issues
    echo
    echo -e "${YELLOW}Debug information:${NC}"
    echo "Display server: ${XDG_SESSION_TYPE:-unknown}"
    echo "DISPLAY: ${DISPLAY:-not set}"
    echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
    echo "QT_QPA_PLATFORM: ${QT_QPA_PLATFORM:-not set}"
    echo
    echo "If running on Wayland, try starting manually first:"
    echo "  /usr/bin/$SERVICE_NAME"
    echo
    exit 1
fi

echo

# Show status
echo -e "${YELLOW}Service status:${NC}"
systemctl --user status $SERVICE_NAME.service --no-pager -l

echo
echo -e "${GREEN}Installation completed successfully!${NC}"
echo
echo "The YAY Update Notifier is now running as a user service."
echo
echo "Useful commands:"
echo "  Start:   systemctl --user start $SERVICE_NAME.service"
echo "  Stop:    systemctl --user stop $SERVICE_NAME.service"
echo "  Status:  systemctl --user status $SERVICE_NAME.service"
echo "  Logs:    journalctl --user -u $SERVICE_NAME.service -f"
echo "  Disable: systemctl --user disable $SERVICE_NAME.service"
echo
echo "The service will automatically start with your desktop session."
echo "Check your system tray for the update notifier icon."
