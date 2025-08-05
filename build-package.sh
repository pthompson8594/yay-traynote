#!/bin/bash
"""
Build YAY Update Notifier Package
Creates a tarball package for distribution
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PACKAGE_NAME="yay-traynote"
VERSION="1.0.0"
BUILD_DIR="build"
PACKAGE_DIR="$BUILD_DIR/$PACKAGE_NAME-$VERSION"

echo -e "${BLUE}Building YAY Update Notifier Package${NC}"
echo "====================================="
echo

# Clean previous builds
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    rm -rf "$BUILD_DIR"
fi

# Create package directory
echo -e "${YELLOW}Creating package structure...${NC}"
mkdir -p "$PACKAGE_DIR"

# Copy files
echo "Copying files..."
cp yay-traynote.py "$PACKAGE_DIR/"
cp yay-traynote-icon.svg "$PACKAGE_DIR/"
cp yay-traynote.service "$PACKAGE_DIR/"
cp setup-sudo.sh "$PACKAGE_DIR/"
cp install.sh "$PACKAGE_DIR/"
cp uninstall.sh "$PACKAGE_DIR/"
cp README.md "$PACKAGE_DIR/"
cp PKGBUILD "$PACKAGE_DIR/"
cp yay-traynote.install "$PACKAGE_DIR/"

# Make scripts executable
chmod +x "$PACKAGE_DIR"/*.sh
chmod +x "$PACKAGE_DIR"/yay-traynote.py

echo -e "${GREEN}✓ Files copied${NC}"

# Create tarball
echo -e "${YELLOW}Creating tarball...${NC}"
cd "$BUILD_DIR"
tar -czf "$PACKAGE_NAME-$VERSION.tar.gz" "$PACKAGE_NAME-$VERSION/"
cd ..

echo -e "${GREEN}✓ Package created: $BUILD_DIR/$PACKAGE_NAME-$VERSION.tar.gz${NC}"

# Show package contents
echo
echo -e "${YELLOW}Package contents:${NC}"
tar -tzf "$BUILD_DIR/$PACKAGE_NAME-$VERSION.tar.gz"

echo
echo -e "${GREEN}Package build completed!${NC}"
echo
echo "Distribution package: $BUILD_DIR/$PACKAGE_NAME-$VERSION.tar.gz"
echo
echo "To install from tarball:"
echo "  tar -xzf $PACKAGE_NAME-$VERSION.tar.gz"
echo "  cd $PACKAGE_NAME-$VERSION"
echo "  ./install.sh"
echo
echo "To build Arch package:"
echo "  cd $PACKAGE_NAME-$VERSION"
echo "  makepkg -si"
