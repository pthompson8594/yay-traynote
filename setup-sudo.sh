#!/bin/bash
"""
Setup passwordless sudo for yay -Sy command
This allows the notifier to sync package databases without prompting for password
"""

# Get current username
USERNAME=$(whoami)

# Create sudoers rule for yay -Sy
SUDOERS_RULE="$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/yay -Sy"

# Path to sudoers.d file
SUDOERS_FILE="/etc/sudoers.d/yay-traynote"

echo "Setting up passwordless sudo for yay -Sy..."
echo "This will allow the notifier to sync package databases without password."
echo
echo "Rule to be added: $SUDOERS_RULE"
echo "File: $SUDOERS_FILE"
echo

# Check if rule already exists
if [ -f "$SUDOERS_FILE" ] && grep -q "$SUDOERS_RULE" "$SUDOERS_FILE"; then
    echo "Sudo rule already exists!"
    exit 0
fi

# Ask for confirmation
read -p "Add this sudo rule? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Create the sudoers file
echo "Creating sudoers rule..."
echo "$SUDOERS_RULE" | sudo tee "$SUDOERS_FILE" > /dev/null

# Set correct permissions
sudo chmod 440 "$SUDOERS_FILE"

# Validate the sudoers file
if sudo visudo -c -f "$SUDOERS_FILE"; then
    echo "✓ Sudoers rule created successfully!"
    echo
    echo "The notifier can now sync package databases without password."
    echo "To remove this rule later, run:"
    echo "  sudo rm $SUDOERS_FILE"
else
    echo "✗ Error: Invalid sudoers syntax!"
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi
