#!/bin/bash

# Create a professional DMG for Snap Window Manager
# This script creates a DMG-only distribution package

set -e  # Exit on any error

# Configuration
APP_NAME="Snap"
DMG_NAME="Snap-WindowManager"
VOLUME_NAME="Snap - Window Manager"
APP_PATH="./dist/snap.app"
DMG_PATH="./${DMG_NAME}.dmg"
TEMP_DMG_PATH="./temp_${DMG_NAME}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are available
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v hdiutil &> /dev/null; then
        print_error "hdiutil is not available. This script requires macOS."
        exit 1
    fi
    
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild is not available. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Build the app if needed
build_app() {
    print_status "Building the application..."
    
    # Check if the app already exists and is recent
    if [ -d "${APP_PATH}" ]; then
        print_warning "App already exists at ${APP_PATH}"
        read -p "Do you want to rebuild? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Using existing app build"
            return
        fi
    fi
    
    # Create dist directory if it doesn't exist
    mkdir -p "./dist"
    
    # Build the app
    print_status "Running xcodebuild..."
    xcodebuild -project snap.xcodeproj -scheme snap -configuration Release -derivedDataPath ./build clean build
    
    # Copy the built app to dist
    if [ -d "./build/Build/Products/Release/snap.app" ]; then
        cp -R "./build/Build/Products/Release/snap.app" "${APP_PATH}"
        print_success "App built successfully"
    else
        print_error "App build failed. Check the build output above."
        exit 1
    fi
}

# Clean up any existing files
cleanup() {
    print_status "Cleaning up existing files..."
    rm -f "${DMG_PATH}"
    rm -f "${TEMP_DMG_PATH}"
    
    # Clean up any mounted volumes
    if [ -d "/Volumes/${VOLUME_NAME}" ]; then
        print_warning "Unmounting existing volume..."
        hdiutil detach "/Volumes/${VOLUME_NAME}" 2>/dev/null || true
    fi
}

# Create the DMG
create_dmg() {
    print_status "Creating DMG..."
    
    # Verify app exists
    if [ ! -d "${APP_PATH}" ]; then
        print_error "App not found at ${APP_PATH}. Please build the app first."
        exit 1
    fi
    
    # Create temporary DMG
    print_status "Creating temporary DMG..."
    hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 20m "${TEMP_DMG_PATH}"
    
    # Mount the temporary DMG
    print_status "Mounting temporary DMG..."
    device=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG_PATH}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    if [ -z "$device" ]; then
        print_error "Failed to mount temporary DMG"
        exit 1
    fi
    
    sleep 2
    
    # Create Applications symlink
    print_status "Creating Applications symlink..."
    ln -sf /Applications "/Volumes/${VOLUME_NAME}/Applications"
    
    # Set volume icon if available
    if [ -f "./snap/Assets.xcassets/Snap.appiconset/icon_512x512.png" ]; then
        print_status "Setting volume icon..."
        # Convert PNG to ICNS for volume icon
        sips -s format icns "./snap/Assets.xcassets/Snap.appiconset/icon_512x512.png" --out "/Volumes/${VOLUME_NAME}/.VolumeIcon.icns" 2>/dev/null || true
        if [ -f "/Volumes/${VOLUME_NAME}/.VolumeIcon.icns" ]; then
            SetFile -c icnC "/Volumes/${VOLUME_NAME}/.VolumeIcon.icns"
            SetFile -a C "/Volumes/${VOLUME_NAME}"
        fi
    fi
    
    # Unmount the temporary DMG
    print_status "Unmounting temporary DMG..."
    hdiutil detach "${device}"
    
    # Convert to final compressed DMG
    print_status "Creating final compressed DMG..."
    hdiutil convert "${TEMP_DMG_PATH}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
    
    # Clean up
    print_status "Cleaning up temporary files..."
    rm -f "${TEMP_DMG_PATH}"
    
    # Verify the final DMG
    if [ -f "${DMG_PATH}" ]; then
        print_success "Professional DMG created: ${DMG_PATH}"
        print_success "Size: $(ls -lh "${DMG_PATH}" | awk '{print $5}')"
        
        # Show DMG info
        print_status "DMG Information:"
        hdiutil imageinfo "${DMG_PATH}" | grep -E "(Format|Checksum|Size)"
    else
        print_error "Failed to create DMG"
        exit 1
    fi
}

# Main execution
main() {
    print_status "Starting DMG creation for Snap Window Manager..."
    print_status "DMG-only build (PKG creation disabled)"
    
    check_dependencies
    build_app
    cleanup
    create_dmg
    
    print_success "DMG creation completed successfully!"
    print_status "You can now distribute: ${DMG_PATH}"
}

# Run main function
main "$@"