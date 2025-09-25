#!/bin/bash

# Snap DMG Build Script
# This script builds the Snap app and creates a DMG installer

set -e  # Exit on any error

# Configuration
APP_NAME="Snap"
BUNDLE_ID="gokulkrishh.snap"
VERSION="1.0"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"

echo "🚀 Building Snap DMG Installer"
echo "================================"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build the app
echo "🔨 Building Snap app..."
xcodebuild -project snap.xcodeproj \
    -scheme snap \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    -archivePath "${BUILD_DIR}/Snap.xcarchive" \
    archive

# Export the app
echo "📦 Exporting app..."
xcodebuild -exportArchive \
    -archivePath "${BUILD_DIR}/Snap.xcarchive" \
    -exportPath "${BUILD_DIR}/Export" \
    -exportOptionsPlist export_options.plist

# Create DMG directory structure
echo "📁 Creating DMG structure..."
mkdir -p "${DMG_TEMP_DIR}"
cp -R "${BUILD_DIR}/Export/Snap.app" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

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