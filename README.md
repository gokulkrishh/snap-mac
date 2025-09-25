# Snap - Window Manager

A macOS menu bar app for organize your windows, boost your productivity. A free and open source software.

## Features

- **Save & Load Layouts**: Capture and restore window arrangements
- **Global Shortcuts**: Assign hotkeys for instant layout switching
- **Replace & Rename**: Update layouts and give them custom names

## Installation

1. Download lastest [Snap-WindowManager.dmg](https://github.com/gokulkrishh/snap-mac/releases)
2. Double-click to mount and drag Snap to Applications
3. Launch Snap from Applications or Spotlight

## Requirements

- macOS 14.0+ (optimized for macOS 26)
- Accessibility permissions (for window management)
- Screen recording permissions (for layout capture)

## Permissions

Snap will request permissions on first launch. If not prompted:

1. System Preferences → Security & Privacy → Privacy
2. Add Snap to Accessibility and Screen Recording
3. Restart Snap

## Building from Source

### Prerequisites

- macOS 14.0+
- Xcode Command Line Tools
- Git

### Build Process

Snap uses a DMG-only distribution system.

#### Quick Build

```bash
./build.sh
```

This will clean, build, sign, and create a DMG automatically.

#### Build Options

```bash
# Clean only (remove build artifacts)
./build.sh --clean-only

# Build without creating DMG
./build.sh --skip-dmg

# Show help
./build.sh --help
```

#### DMG Creation Only

If you already have a built app and only want to create a DMG:

```bash
./create_dmg.sh
```

### Build Output

- **DMG File:** `Snap-WindowManager.dmg`
- **App Location:** `./dist/snap.app`
- **Build Directory:** `./build/` (temporary)

### Features of the DMG

- Professional layout with Applications symlink
- Volume icon from app assets
- Compressed format for smaller file size
- Ready for distribution

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
