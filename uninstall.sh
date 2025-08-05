#!/bin/bash
"""
YAY Update Notifier Uninstallation Script
Removes the notifier service and files
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
SUDOERS_FILE="/etc/sudoers.d/yay-traynote"

echo -e "${BLUE}YAY Update Notifier Uninstallation${NC}"
echo "===================================="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root!${NC}"
    echo "Run as your regular user. The script will ask for sudo when needed."
    exit 1
fi

# Stop and disable service
echo -e "${YELLOW}Stopping and disabling service...${NC}"
systemctl --user stop $SERVICE_NAME.service 2>/dev/null || true
systemctl --user disable $SERVICE_NAME.service 2>/dev/null || true
echo -e "${GREEN}✓ Service stopped and disabled${NC}"

# Remove files
echo -e "${YELLOW}Removing installed files...${NC}"

# Remove main script
if [ -f "$INSTALL_DIR/$SERVICE_NAME" ]; then
    sudo rm "$INSTALL_DIR/$SERVICE_NAME"
    echo "✓ Removed $INSTALL_DIR/$SERVICE_NAME"
fi

# Remove icon
if [ -f "$ICON_DIR/yay-traynote-icon.svg" ]; then
    sudo rm "$ICON_DIR/yay-traynote-icon.svg"
    echo "✓ Removed $ICON_DIR/yay-traynote-icon.svg"
fi

# Remove service file
if [ -f "$SERVICE_DIR/$SERVICE_NAME.service" ]; then
    sudo rm "$SERVICE_DIR/$SERVICE_NAME.service"
    echo "✓ Removed $SERVICE_DIR/$SERVICE_NAME.service"
fi

# Remove sudoers file
if [ -f "$SUDOERS_FILE" ]; then
    echo -e "${YELLOW}Removing passwordless sudo rule...${NC}"
    read -p "Remove passwordless sudo rule for yay -Sy? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm "$SUDOERS_FILE"
        echo "✓ Removed $SUDOERS_FILE"
    else
        echo "! Keeping passwordless sudo rule"
    fi
fi

# Reload systemd
echo -e "${YELLOW}Reloading systemd...${NC}"
systemctl --user daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

# Remove config directory (optional)
CONFIG_DIR="$HOME/.config/yay-traynote"
if [ -d "$CONFIG_DIR" ]; then
    echo
    read -p "Remove configuration directory $CONFIG_DIR? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo "✓ Removed $CONFIG_DIR"
    else
        echo "! Keeping configuration directory"
    fi
fi

echo
echo -e "${GREEN}Uninstallation completed!${NC}"
echo
echo "YAY Update Notifier has been removed from your system."
