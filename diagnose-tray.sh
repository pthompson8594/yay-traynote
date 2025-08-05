#!/bin/bash
# Diagnose system tray issues

echo "=== YAY Update Notifier System Tray Diagnostics ==="
echo

echo "1. Environment Information:"
echo "   Desktop Environment: ${XDG_CURRENT_DESKTOP:-unknown}"
echo "   Session Type: ${XDG_SESSION_TYPE:-unknown}"
echo "   Desktop Session: ${DESKTOP_SESSION:-unknown}"
echo "   Display: ${DISPLAY:-not set}"
echo "   Wayland Display: ${WAYLAND_DISPLAY:-not set}"
echo

echo "2. Service Status:"
systemctl --user status yay-traynote.service --no-pager -l
echo

echo "3. Process Check:"
if pgrep -f yay-traynote > /dev/null; then
    echo "   ✓ yay-traynote process is running"
    echo "   PIDs: $(pgrep -f yay-traynote | tr '\n' ' ')"
else
    echo "   ✗ yay-traynote process not found"
fi
echo

echo "4. System Tray Support Check:"
case "${XDG_CURRENT_DESKTOP,,}" in
    *gnome*)
        echo "   Desktop: GNOME detected"
        if command -v gnome-extensions &> /dev/null; then
            if gnome-extensions list --enabled | grep -i tray &> /dev/null; then
                echo "   ✓ System tray extension appears to be enabled"
            else
                echo "   ⚠ System tray extension may not be enabled"
                echo "   Try: gnome-extensions enable trayIconsReloaded@selfmade.pl"
                echo "   Or install: https://extensions.gnome.org/extension/2890/tray-icons-reloaded/"
            fi
        else
            echo "   ⚠ Cannot check GNOME extensions"
        fi
        ;;
    *kde*|*plasma*)
        echo "   Desktop: KDE/Plasma detected"
        echo "   ✓ KDE has built-in system tray support"
        ;;
    *xfce*)
        echo "   Desktop: XFCE detected"
        echo "   ✓ XFCE has built-in system tray support"
        ;;
    *sway*)
        echo "   Desktop: Sway detected"
        echo "   ⚠ Sway may need waybar or similar for system tray"
        ;;
    *)
        echo "   Desktop: ${XDG_CURRENT_DESKTOP:-Unknown}"
        echo "   ⚠ Unknown desktop environment"
        ;;
esac
echo

echo "5. Icon File Check:"
if [ -f "yay-updater-icon.svg" ]; then
    echo "   ✓ Icon file exists in current directory"
elif [ -f "/usr/share/pixmaps/yay-traynote-icon.svg" ]; then
    echo "   ✓ Icon file exists in system location"
else
    echo "   ✗ Icon file not found"
fi
echo

echo "6. Qt Platform Check:"
echo "   QT_QPA_PLATFORM: ${QT_QPA_PLATFORM:-not set}"
python3 -c "
try:
    from PyQt6.QtWidgets import QApplication, QSystemTrayIcon
    import sys
    app = QApplication(sys.argv)
    if QSystemTrayIcon.isSystemTrayAvailable():
        print('   ✓ Qt reports system tray is available')
    else:
        print('   ✗ Qt reports system tray is NOT available')
except Exception as e:
    print(f'   ✗ Qt check failed: {e}')
"
echo

echo "7. Troubleshooting Suggestions:"
echo "   • Check if your desktop environment supports system tray"
echo "   • For GNOME: Install 'Tray Icons: Reloaded' extension"
echo "   • For Sway: Install waybar with tray module"
echo "   • Try running manually: python3 yay-traynote.py"
echo "   • Check service logs: journalctl --user -u yay-traynote.service -f"
echo

echo "8. Manual Test:"
echo "   Run this to test manually:"
echo "   python3 $(pwd)/yay-traynote.py"
