#!/bin/bash

# Snap Window Manager - Build Script
# This script builds the app and creates a DMG-only distribution package
# PKG creation has been removed as requested

set -e  # Exit on any error

# Configuration
PROJECT_NAME="snap"
SCHEME_NAME="snap"
APP_NAME="Snap"
DMG_NAME="Snap-WindowManager"
VOLUME_NAME="Snap - Window Manager"
BUILD_DIR="./build"
DIST_DIR="./dist"
APP_PATH="${DIST_DIR}/${PROJECT_NAME}.app"
DMG_PATH="./${DMG_NAME}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  Snap Window Manager Builder  ${NC}"
    echo -e "${PURPLE}================================${NC}"
}

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
    
    local missing_deps=()
    
    if ! command -v xcodebuild &> /dev/null; then
        missing_deps+=("xcodebuild")
    fi
    
    if ! command -v hdiutil &> /dev/null; then
        missing_deps+=("hdiutil")
    fi
    
    if ! command -v codesign &> /dev/null; then
        missing_deps+=("codesign")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_deps[*]}"
        print_error "Please install Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Clean previous builds
clean_build() {
    print_status "Cleaning previous builds..."
    
    # Remove build directories
    rm -rf "${BUILD_DIR}"
    rm -rf "${DIST_DIR}"
    
    # Remove existing DMG
    rm -f "${DMG_PATH}"
    rm -f "./temp_${DMG_NAME}.dmg"
    
    # Clean Xcode build cache
    xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" clean
    
    print_success "Clean completed"
}

# Build the application
build_app() {
    print_status "Building ${APP_NAME}..."
    
    # Create directories
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${DIST_DIR}"
    
    # Build the app
    print_status "Running xcodebuild..."
    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME_NAME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}" \
        build
    
    # Find the built app
    local built_app_path
    built_app_path=$(find "${BUILD_DIR}" -name "*.app" -type d | head -1)
    
    if [ -z "$built_app_path" ]; then
        print_error "App build failed. No .app bundle found."
        exit 1
    fi
    
    # Copy to dist directory
    cp -R "$built_app_path" "${APP_PATH}"
    
    print_success "App built successfully: ${APP_PATH}"
}

# Code sign the app (if needed)
code_sign() {
    print_status "Checking code signing..."
    
    # Check if we have a development team
    local team_id
    team_id=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -showBuildSettings | grep DEVELOPMENT_TEAM | head -1 | awk '{print $3}')
    
    if [ -n "$team_id" ] && [ "$team_id" != "" ]; then
        print_status "Code signing with team: ${team_id}"
        codesign --force --deep --sign "${team_id}" "${APP_PATH}"
        print_success "App code signed successfully"
    else
        print_warning "No development team configured. App will be ad-hoc signed."
        codesign --force --deep --sign - "${APP_PATH}"
    fi
}

# Verify the app
verify_app() {
    print_status "Verifying app..."
    
    # Check if app is valid
    if [ ! -d "${APP_PATH}" ]; then
        print_error "App not found at ${APP_PATH}"
        exit 1
    fi
    
    # Check app size
    local app_size
    app_size=$(du -sh "${APP_PATH}" | cut -f1)
    print_status "App size: ${app_size}"
    
    # Verify code signature
    if codesign -v "${APP_PATH}" 2>/dev/null; then
        print_success "App signature is valid"
    else
        print_warning "App signature verification failed"
    fi
    
    print_success "App verification completed"
}

# Create DMG using the existing script
create_dmg() {
    print_status "Creating DMG distribution package..."
    
    # Use the existing create_dmg.sh script
    if [ -f "./create_dmg.sh" ]; then
        chmod +x "./create_dmg.sh"
        ./create_dmg.sh
    else
        print_error "create_dmg.sh script not found"
        exit 1
    fi
}

# Show build summary
show_summary() {
    print_header
    echo -e "${GREEN}Build Summary:${NC}"
    echo -e "  • App: ${APP_PATH}"
    echo -e "  • DMG: ${DMG_PATH}"
    
    if [ -f "${DMG_PATH}" ]; then
        local dmg_size
        dmg_size=$(ls -lh "${DMG_PATH}" | awk '{print $5}')
        echo -e "  • DMG Size: ${dmg_size}"
    fi
    
    echo -e "${BLUE}Distribution:${NC}"
    echo -e "  • DMG-only distribution (PKG removed)"
    echo -e "  • Ready for distribution: ${DMG_PATH}"
    
    print_success "Build completed successfully!"
}

# Main execution
main() {
    print_header
    
    # Parse command line arguments
    local clean_only=false
    local skip_dmg=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-only)
                clean_only=true
                shift
                ;;
            --skip-dmg)
                skip_dmg=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --clean-only    Only clean build artifacts"
                echo "  --skip-dmg      Skip DMG creation"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_dependencies
    clean_build
    
    if [ "$clean_only" = true ]; then
        print_success "Clean completed. Exiting."
        exit 0
    fi
    
    build_app
    code_sign
    verify_app
    
    if [ "$skip_dmg" = false ]; then
        create_dmg
    fi
    
    show_summary
}

# Run main function
main "$@"