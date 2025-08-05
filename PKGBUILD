# Maintainer: Your Name <your.email@example.com>

pkgname=yay-traynote
pkgver=1.0.0
pkgrel=1
pkgdesc="Lightweight system tray notifier for Arch Linux package updates using yay"
arch=('any')
url="https://github.com/yourusername/yay-traynote"
license=('MIT')
depends=('python' 'python-pyqt6' 'yay' 'systemd')
makedepends=()
backup=()
options=()
install=yay-traynote.install
source=("yay-traynote.py"
        "yay-traynote-icon.svg"
        "yay-traynote.service"
        "setup-sudo.sh")
sha256sums=('SKIP'
            'SKIP'
            'SKIP'
            'SKIP')

package() {
    # Install main script
    install -Dm755 "$srcdir/yay-traynote.py" "$pkgdir/usr/bin/yay-traynote"
    
    # Install icon
    install -Dm644 "$srcdir/yay-traynote-icon.svg" "$pkgdir/usr/share/pixmaps/yay-traynote-icon.svg"
    
    # Install systemd user service
    install -Dm644 "$srcdir/yay-traynote.service" "$pkgdir/usr/lib/systemd/user/yay-traynote.service"
    
    # Install sudo setup script
    install -Dm755 "$srcdir/setup-sudo.sh" "$pkgdir/usr/share/yay-traynote/setup-sudo.sh"
    
    # Create documentation directory
    install -dm755 "$pkgdir/usr/share/doc/yay-traynote"
    
    # Install README if it exists
    if [ -f "$srcdir/README.md" ]; then
        install -Dm644 "$srcdir/README.md" "$pkgdir/usr/share/doc/yay-traynote/README.md"
    fi
}
