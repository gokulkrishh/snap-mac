# Snap - Window Manager

A powerful macOS menu bar application for managing window layouts with keyboard shortcuts.

## Features

- **Save Window Layouts**: Capture your current window arrangement and save it for later use
- **Load Layouts**: Instantly restore saved window arrangements
- **Global Keyboard Shortcuts**: Assign custom hotkeys to quickly switch between layouts
- **Smart Menu Interface**: Dynamic menu labels and intuitive controls
- **Replace & Rename**: Update existing layouts or give them custom names
- **Settings Integration**: Launch at login, apply to all monitors, and more

## Installation

1. Download `Snap-WindowManager.dmg`
2. Double-click the DMG file to mount it
3. Drag the Snap app to your Applications folder
4. Launch Snap from Applications or Spotlight

## Usage

### Basic Operations

1. **Save Layout**: Click the Snap menu bar icon → "Save layout"
2. **Load Layout**: Click the Snap menu bar icon → Select a saved layout → "Load layout"
3. **Record Shortcut**: Click the Snap menu bar icon → Select a layout → "Record shortcut"

### Keyboard Shortcuts

- Assign custom keyboard shortcuts to your layouts for instant switching
- Use any combination of ⌘, ⌥, ⌃, ⇧ modifiers
- Shortcuts work globally across all applications

### Menu Features

- **Smart Labels**: Menu shows "Record shortcut" or "Update shortcut" based on current state
- **Persistent Menu**: Menu stays open for management actions, closes only for "Load" or "Quit"
- **Visual Feedback**: See shortcuts displayed next to layout names

## System Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permissions (required for window management)
- Screen recording permissions (required for layout capture)

## Permissions

On first launch, Snap will request:
- **Accessibility Access**: Required to move and resize windows
- **Screen Recording Access**: Required to capture window positions

Grant these permissions in System Preferences → Security & Privacy → Privacy.

## Troubleshooting

### Launch at Login Issues
If automatic login item setup fails (common in sandboxed environments):
1. Go to System Preferences → Users & Groups → Login Items
2. Click the "+" button and add Snap manually

### Shortcuts Not Working
- Ensure Snap has Accessibility permissions
- Check that the shortcut isn't already used by another application
- Try recording the shortcut again

### Layout Not Loading
- Verify the applications are still running
- Some applications may not support window positioning
- Try saving and loading the layout again

## Support

For issues or feature requests, please contact the developer.

## Version History

- **1.0.0**: Initial release with core window management features
  - Save, load, replace, rename, and delete layouts
  - Global keyboard shortcuts
  - Smart menu interface
  - Settings integration

---

**Snap** - Organize your windows, boost your productivity.