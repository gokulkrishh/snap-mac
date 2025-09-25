#!/bin/bash

# Create a professional DMG for Snap Window Manager
APP_NAME="Snap"
DMG_NAME="Snap-WindowManager"
VOLUME_NAME="Snap - Window Manager"
APP_PATH="./dist/snap.app"
DMG_PATH="./${DMG_NAME}.dmg"
TEMP_DMG_PATH="./temp_${DMG_NAME}.dmg"

# Clean up any existing files
rm -f "${DMG_PATH}"
rm -f "${TEMP_DMG_PATH}"

# Create temporary DMG
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 10m "${TEMP_DMG_PATH}"

# Mount the temporary DMG
device=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG_PATH}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# Create Applications symlink
ln -s /Applications "/Volumes/${VOLUME_NAME}/Applications"

# Create a background image (optional)
# You can add a background image here if you have one

# Set volume icon (optional)
# cp "icon.icns" "/Volumes/${VOLUME_NAME}/.VolumeIcon.icns"
# SetFile -c icnC "/Volumes/${VOLUME_NAME}/.VolumeIcon.icns"

# Set the volume to use the custom icon
# SetFile -a C "/Volumes/${VOLUME_NAME}"

# Unmount the temporary DMG
hdiutil detach "${device}"

# Convert to final compressed DMG
hdiutil convert "${TEMP_DMG_PATH}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"

# Clean up
rm -f "${TEMP_DMG_PATH}"

echo "✅ Professional DMG created: ${DMG_PATH}"
echo "📦 Size: $(ls -lh "${DMG_PATH}" | awk '{print $5}')"