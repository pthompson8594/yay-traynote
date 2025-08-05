#!/usr/bin/env python3
"""
YAY Update Notifier - Simple notification-only version
Shows desktop notifications when package updates are available
"""

import sys
import os
import json
import subprocess
import threading
import time
import math
import fcntl
import tempfile
import signal
from datetime import datetime, timedelta
from PyQt6.QtCore import QTimer, Qt, QThread, pyqtSignal
import atexit
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QMessageBox
from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QAction

# Constants
SYNC_TIMEOUT = 30  # seconds for yay sync
CHECK_TIMEOUT = 60  # seconds for yay check
FLASH_INTERVAL = 50  # milliseconds for smooth animation
SIGNAL_CHECK_INTERVAL = 500  # milliseconds for signal processing
UPDATE_CHECK_DELAY = 1000  # milliseconds delay after yay completion
FLASH_CYCLE_SLOW = 3.0  # seconds for updates available flash
FLASH_CYCLE_FAST = 0.8  # seconds for checking flash

class SingleInstance:
    """Ensures only one instance of the application runs at a time"""
    
    def __init__(self, lock_file_name):
        self.lock_file_name = lock_file_name
        self.lock_file_path = os.path.join(tempfile.gettempdir(), lock_file_name)
        self.lock_file = None
        
    def __enter__(self):
        try:
            self.lock_file = open(self.lock_file_path, 'w')
            fcntl.lockf(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            
            # Write PID to lock file
            self.lock_file.write(str(os.getpid()))
            self.lock_file.flush()
            
            # Register cleanup on exit
            atexit.register(self.cleanup)
            return True
            
        except (IOError, OSError):
            # Another instance is already running
            if self.lock_file:
                self.lock_file.close()
                self.lock_file = None
            return False
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.cleanup()
    
    def cleanup(self):
        """Clean up lock file"""
        if self.lock_file:
            try:
                fcntl.lockf(self.lock_file, fcntl.LOCK_UN)
                self.lock_file.close()
                os.unlink(self.lock_file_path)
            except (IOError, OSError):
                pass
            self.lock_file = None

class SettingsManager:
    """Manages application settings"""
    
    def __init__(self):
        self.config_dir = os.path.expanduser("~/.config/yay-traynote")
        self.settings_file = os.path.join(self.config_dir, "settings.json")
        self.settings = self.load_settings()
    
    def load_settings(self):
        """Load settings from file"""
        default_settings = {
            "check_interval": 3600,  # 1 hour in seconds
            "last_check": None
        }
        
        if not os.path.exists(self.config_dir):
            os.makedirs(self.config_dir)
        
        if os.path.exists(self.settings_file):
            try:
                with open(self.settings_file, 'r') as f:
                    loaded_settings = json.load(f)
                    default_settings.update(loaded_settings)
            except (json.JSONDecodeError, IOError):
                pass
        
        return default_settings
    
    def save_settings(self):
        """Save settings to file"""
        try:
            with open(self.settings_file, 'w') as f:
                json.dump(self.settings, f, indent=2)
        except IOError:
            pass
    
    def get(self, key, default=None):
        """Get a setting value"""
        return self.settings.get(key, default)
    
    def set(self, key, value):
        """Set a setting value"""
        self.settings[key] = value
        self.save_settings()

class UpdateChecker(QThread):
    """Thread for checking updates without blocking UI"""
    
    updates_found = pyqtSignal(list)
    check_completed = pyqtSignal()
    
    def run(self):
        """Check for available updates"""
        try:
            # Verify yay is available
            yay_check = subprocess.run(['which', 'yay'], 
                                     capture_output=True, 
                                     timeout=5)
            if yay_check.returncode != 0:
                return  # yay not found, silently fail
            
            # First sync the package database
            sync_result = subprocess.run(['sudo', 'yay', '-Sy'], 
                                       capture_output=True, 
                                       text=True, 
                                       timeout=SYNC_TIMEOUT)
            
            # Then check for updates using yay
            result = subprocess.run(['yay', '-Qu'], 
                                  capture_output=True, 
                                  text=True, 
                                  timeout=CHECK_TIMEOUT)
            
            if result.returncode == 0 and result.stdout.strip():
                # Parse update output
                updates = []
                for line in result.stdout.strip().split('\n'):
                    if line.strip() and ' -> ' in line:
                        package_info = line.split(' -> ')
                        if len(package_info) >= 2:
                            package_name = package_info[0].strip()
                            new_version = package_info[1].strip()
                            updates.append({'name': package_name, 'version': new_version})
                
                if updates:
                    self.updates_found.emit(updates)
            
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        self.check_completed.emit()

class UpdateNotifier(QSystemTrayIcon):
    """Simple system tray notifier for package updates"""
    
    def __init__(self, icon_path):
        super().__init__()
        
        self.settings_manager = SettingsManager()
        self.icon_path = icon_path
        self.updates_available = False
        self.yay_running = False  # Track if yay terminal is open
        
        # Icon cache for performance - store brightness-adjusted icons
        self.icon_cache = {}  # brightness_factor -> QIcon
        
        # Create icon
        self.create_icon()
        
        # Setup context menu
        self.setup_menu()
        
        # Setup update checker
        self.update_checker = UpdateChecker()
        self.update_checker.updates_found.connect(self.on_updates_found)
        self.update_checker.check_completed.connect(self.on_check_completed)
        
        # Setup timer for periodic checks
        self.check_timer = QTimer()
        self.check_timer.timeout.connect(self.check_for_updates)
        self.start_periodic_checks()
        
        # Icon state and smooth flashing (like icontest.py)
        self.icon_state = 'idle'  # 'idle', 'updates_available', 'checking'
        
        # Smooth gradient flashing control
        self.flash_timer = QTimer()
        self.flash_timer.timeout.connect(self.update_gradient_flash)
        # Don't start timer yet - only when needed
        
        # Gradient flashing state
        self.flash_time = 0.0  # Current time in flash cycle
        self.flash_cycle_duration = 3.0  # Duration of full flash cycle in seconds
        self.brightness_factor = 1.0  # Start at normal brightness
        
        # Initial check
        self.check_for_updates()
    
    def cleanup(self):
        """Clean up resources on exit"""
        # Stop timers
        if self.flash_timer.isActive():
            self.flash_timer.stop()
        if self.check_timer.isActive():
            self.check_timer.stop()
            
        # Clear icon cache
        self.icon_cache.clear()
            
        # Terminate update checker thread if running
        if self.update_checker.isRunning():
            self.update_checker.terminate()
            self.update_checker.wait(3000)  # Wait up to 3 seconds
            if self.update_checker.isRunning():
                self.update_checker.kill()  # Force kill if needed
    
    def create_icon(self):
        """Create system tray icon"""
        if os.path.exists(self.icon_path):
            self.default_icon = QIcon(self.icon_path)
        else:
            # Create a simple fallback icon
            pixmap = QPixmap(24, 24)
            pixmap.fill(QColor(100, 100, 100))
            painter = QPainter(pixmap)
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, "U")
            painter.end()
            self.default_icon = QIcon(pixmap)
        
        self.setIcon(self.default_icon)
        self.setToolTip("Yay Update Notifier")
    
    def setup_menu(self):
        """Setup system tray context menu"""
        menu = QMenu()
        
        # Check now action
        check_action = QAction("Check for Updates Now", self)
        check_action.triggered.connect(self.check_for_updates)
        menu.addAction(check_action)
        
        # Run yay action
        yay_action = QAction("Run YAY Updates", self)
        yay_action.triggered.connect(self.run_yay_terminal)
        menu.addAction(yay_action)
        
        menu.addSeparator()
        
        # Settings submenu
        settings_menu = menu.addMenu("Settings")
        
        # Check interval options
        interval_menu = settings_menu.addMenu("Check Interval")
        
        intervals = [
            ("30 minutes", 1800),
            ("1 hour", 3600),
            ("2 hours", 7200),
            ("6 hours", 21600),
            ("12 hours", 43200),
            ("Daily", 86400)
        ]
        
        current_interval = self.settings_manager.get("check_interval", 3600)
        
        for label, seconds in intervals:
            action = QAction(label, self)
            action.setCheckable(True)
            action.setChecked(seconds == current_interval)
            action.triggered.connect(lambda checked, s=seconds: self.set_check_interval(s))
            interval_menu.addAction(action)
        
        # Clear updates action (stops flashing)
        clear_action = QAction("Clear Update Alert", self)
        clear_action.triggered.connect(self.clear_updates)
        settings_menu.addAction(clear_action)
        
        menu.addSeparator()
        
        # About action
        about_action = QAction("About", self)
        about_action.triggered.connect(self.show_about)
        menu.addAction(about_action)
        
        self.setContextMenu(menu)
    
    def set_check_interval(self, seconds):
        """Set the update check interval"""
        self.settings_manager.set("check_interval", seconds)
        self.start_periodic_checks()
        
        # Update menu checkmarks
        menu = self.contextMenu()
        settings_menu = menu.actions()[2].menu()  # Settings submenu
        interval_menu = settings_menu.actions()[0].menu()  # Check Interval submenu
        
        for action in interval_menu.actions():
            action.setChecked(False)
        
        # Find and check the correct action
        for action in interval_menu.actions():
            if action.data() == seconds:
                action.setChecked(True)
                break
    
    def clear_updates(self):
        """Clear update alert (stop flashing)"""
        self.updates_available = False
        self.icon_state = 'idle'
        self.setToolTip("YAY Update Notifier - Alert cleared")
    
    def run_yay_terminal(self):
        """Open terminal and run yay, then check for updates when done"""
        if self.yay_running:
            QMessageBox.information(None, "YAY Already Running", 
                                  "YAY terminal is already open. Please close it first.")
            return
            
        try:
            self.yay_running = True
            # Launch yay in a new terminal window
            # Using gnome-terminal as it's common on many systems
            # The command will close the terminal after yay completes
            process = subprocess.Popen([
                'gnome-terminal', '--', 'bash', '-c', 
                'echo "Running YAY package manager..."; yay; echo "Press Enter to close..."; read'
            ])
            
            # Start a thread to monitor when the terminal process ends
            def monitor_yay_completion():
                try:
                    process.wait()  # Wait for terminal to close
                finally:
                    self.yay_running = False
                    # Schedule update check on main thread using QTimer
                    QTimer.singleShot(UPDATE_CHECK_DELAY, self.check_for_updates)
            
            # Run monitoring in background thread
            monitor_thread = threading.Thread(target=monitor_yay_completion, daemon=True)
            monitor_thread.start()
            
        except FileNotFoundError:
            # Fallback to other common terminals if gnome-terminal not available
            try:
                process = subprocess.Popen([
                    'konsole', '-e', 'bash', '-c',
                    'echo "Running YAY package manager..."; yay; echo "Press Enter to close..."; read'
                ])
                
                def monitor_yay_completion():
                    try:
                        process.wait()
                    finally:
                        self.yay_running = False
                        QTimer.singleShot(UPDATE_CHECK_DELAY, self.check_for_updates)
                
                monitor_thread = threading.Thread(target=monitor_yay_completion, daemon=True)
                monitor_thread.start()
                
            except FileNotFoundError:
                # Final fallback to xterm
                try:
                    process = subprocess.Popen([
                        'xterm', '-e', 'bash', '-c',
                        'echo "Running YAY package manager..."; yay; echo "Press Enter to close..."; read'
                    ])
                    
                    def monitor_yay_completion():
                        try:
                            process.wait()
                        finally:
                            self.yay_running = False
                            QTimer.singleShot(UPDATE_CHECK_DELAY, self.check_for_updates)
                    
                    monitor_thread = threading.Thread(target=monitor_yay_completion, daemon=True)
                    monitor_thread.start()
                    
                except FileNotFoundError:
                    # If no terminal available, show error message
                    QMessageBox.warning(None, "Terminal Not Found", 
                                      "Could not find a suitable terminal emulator.\n"
                                      "Please install gnome-terminal, konsole, or xterm.")
        except Exception as e:
            self.yay_running = False  # Reset flag on error
            QMessageBox.warning(None, "Error", f"Failed to launch terminal: {str(e)}")
    
    def start_periodic_checks(self):
        """Start the periodic update checking timer"""
        interval = self.settings_manager.get("check_interval", 3600) * 1000  # Convert to milliseconds
        self.check_timer.start(interval)
    
    def check_for_updates(self):
        """Initiate update check"""
        if not self.update_checker.isRunning():
            # Reset state for new check
            self.updates_available = False
            self.icon_state = 'checking'
            self.flash_time = 0.0
            # Start flash timer for checking animation
            if not self.flash_timer.isActive():
                self.flash_timer.start(FLASH_INTERVAL)
            self.setToolTip("YAY Update Notifier - Checking for updates...")
            self.update_checker.start()
    
    def update_gradient_flash(self):
        """Update smooth gradient flash like icontest.py"""
        if self.icon_state == 'idle':
            # No flashing, solid icon - stop timer for performance
            self.flash_timer.stop()
            self.brightness_factor = 1.0
            self.setIcon(self.default_icon)
            return
            
        # Increment time based on timer interval (50ms = 0.05s)
        self.flash_time += 0.05
        
        # Set cycle duration based on state
        if self.icon_state == 'updates_available':
            self.flash_cycle_duration = FLASH_CYCLE_SLOW
        elif self.icon_state == 'checking':
            self.flash_cycle_duration = FLASH_CYCLE_FAST
        
        # Reset cycle time if needed
        if self.flash_time >= self.flash_cycle_duration:
            self.flash_time = 0.0
        
        # Calculate smooth brightness using sine wave (ranges from 0.5 to 1.0)
        # This creates a smooth fade in/out effect
        brightness_range = 0.5  # Fade between 50% and 100% brightness
        brightness_offset = 0.5  # Minimum brightness
        sine_value = math.sin(2 * math.pi * self.flash_time / self.flash_cycle_duration)
        self.brightness_factor = brightness_offset + (brightness_range * (sine_value + 1) / 2)
        
        # Apply the smooth brightness change
        new_icon = self.apply_brightness(self.default_icon, self.brightness_factor)
        self.setIcon(new_icon)
    
    def apply_brightness(self, icon, factor):
        """Apply brightness factor to icon with caching for performance"""
        if factor >= 1.0:
            return icon  # No change needed
            
        # Round factor to reduce cache size while maintaining smoothness
        cache_key = round(factor, 3)  # 3 decimal places = 1000 possible values
        
        # Check cache first
        if cache_key in self.icon_cache:
            return self.icon_cache[cache_key]
            
        # Create new brightness-adjusted icon
        pixmap = icon.pixmap(32, 32).copy()  # Make a copy to avoid modifying original
        
        # Create a semi-transparent version by adjusting alpha
        painter = QPainter(pixmap)
        painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_DestinationIn)
        painter.fillRect(pixmap.rect(), QColor(0, 0, 0, int(255 * factor)))
        painter.end()

        # Cache the result
        cached_icon = QIcon(pixmap)
        self.icon_cache[cache_key] = cached_icon
        return cached_icon
    
    def on_updates_found(self, updates):
        """Called when updates are found - start flashing"""
        self.updates_available = True
        self.icon_state = 'updates_available'
        count = len(updates)
        
        # Update tooltip
        self.setToolTip(f"YAY Update Notifier - {count} updates available")
        
        # Reset flash time when changing states and ensure timer is running
        self.flash_time = 0.0
        if not self.flash_timer.isActive():
            self.flash_timer.start(FLASH_INTERVAL)
        
        # Save last check time
        now = datetime.now()
        self.settings_manager.set("last_check", now.isoformat())
    
    def on_check_completed(self):
        """Called when update check is completed"""
        # If no updates were found during this check cycle, clear the alert
        if not self.updates_available:
            self.icon_state = 'idle'
            self.setToolTip("YAY Update Notifier - No updates available")
        
        # Save last check time
        now = datetime.now()
        self.settings_manager.set("last_check", now.isoformat())
    
    def show_about(self):
        """Show about dialog"""
        msg = QMessageBox()
        msg.setWindowIcon(QIcon(self.icon_path))
        msg.setWindowTitle("About YAY Update Notifier")
        msg.setText("YAY Update Notifier v1.0\n\n"
                   "A simple system tray application that checks for\n"
                   "Arch Linux package updates using yay and shows\n"
                   "desktop notifications when updates are available.\n\n"
                   "Click the system tray icon to access settings.")
        msg.setStandardButtons(QMessageBox.StandardButton.Ok)
        msg.exec()

def main():
    """Main application entry point"""
    
    # Ensure only one instance runs
    with SingleInstance("yay-traynote.lock") as instance:
        if not instance:
            print("YAY Update Notifier is already running.")
            sys.exit(1)
        
        app = QApplication(sys.argv)
        app.setQuitOnLastWindowClosed(False)
        
        # Setup signal handling for Ctrl+C
        def signal_handler(sig, frame):
            if 'notifier' in locals():
                notifier.cleanup()
            app.quit()
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        # Create a timer to allow signal processing - optimize frequency
        signal_timer = QTimer()
        signal_timer.start(SIGNAL_CHECK_INTERVAL)
        signal_timer.timeout.connect(lambda: None)  # Empty slot to process signals
        
        # Check if system tray is available
        if not QSystemTrayIcon.isSystemTrayAvailable():
            QMessageBox.critical(None, "System Tray", 
                               "System tray is not available on this system.")
            sys.exit(1)
        
        # Determine icon path - try multiple locations
        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_paths = [
            os.path.join(script_dir, "yay-traynote-icon.svg"),  # Local directory
            "/usr/share/pixmaps/yay-traynote-icon.svg",      # System location
            "/usr/share/pixmaps/yay-traynote-icon.svg"          # Alternate system location
        ]
        
        icon_path = None
        for path in icon_paths:
            if os.path.exists(path):
                icon_path = path
                break
        
        if not icon_path:
            icon_path = icon_paths[0]  # Fallback to first option
        
        # Create and show notifier
        notifier = UpdateNotifier(icon_path)
        notifier.show()
        
        sys.exit(app.exec())

if __name__ == "__main__":
    main()
