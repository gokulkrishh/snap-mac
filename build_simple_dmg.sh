#!/bin/bash

# Simple Snap DMG Build Script (No Code Signing)
# This script builds the Snap app and creates a DMG installer without code signing

set -e  # Exit on any error

# Configuration
APP_NAME="Snap"
VERSION="1.0"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"

echo "🚀 Building Snap DMG Installer (Simple)"
echo "======================================="

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build the app in Release mode
echo "🔨 Building Snap app..."
xcodebuild -project snap.xcodeproj \
    -scheme snap \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    build

# Copy the built app
echo "📦 Copying built app..."
cp -R "${BUILD_DIR}/DerivedData/Build/Products/Release/Snap.app" "${BUILD_DIR}/"

# Create DMG directory structure
echo "📁 Creating DMG structure..."
mkdir -p "${DMG_TEMP_DIR}"
cp -R "${BUILD_DIR}/Snap.app" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create a simple README
cat > "${DMG_TEMP_DIR}/README.txt" << EOF
Snap - Window Management Tool

Installation:
1. Drag Snap.app to the Applications folder
2. Launch Snap from Applications
3. Grant accessibility permissions when prompted

Usage:
- Click the Snap icon in the menu bar
- Create layouts by arranging windows and saving them
- Use keyboard shortcuts to quickly apply layouts

System Requirements:
- macOS 26.0 or later
- Accessibility permissions

For support, visit: https://github.com/gokulkrishh/snap-mac
EOF

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDZO \
    "${BUILD_DIR}/${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

echo "✅ DMG created successfully: ${BUILD_DIR}/${DMG_NAME}"
echo "📏 DMG size: $(du -h "${BUILD_DIR}/${DMG_NAME}" | cut -f1)"

# Optional: Open DMG in Finder
read -p "🔍 Open DMG in Finder? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "${BUILD_DIR}/${DMG_NAME}"
fi

echo "🎉 Build complete!"
echo ""
echo "📝 Note: This DMG is not code-signed."
echo "   Users may need to right-click and 'Open' the app"
echo "   to bypass Gatekeeper security warnings."