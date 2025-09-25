# Snap - Window Manager

A powerful macOS menu bar application for managing window layouts with keyboard shortcuts. Features a beautiful dynamic icon that adapts to system appearance and provides an intuitive interface for window management.

## ✨ Features

- **🎨 Dynamic Icon**: Beautiful Icon Composer design with automatic light/dark mode adaptation
- **💾 Save Window Layouts**: Capture your current window arrangement and save it for later use
- **⚡ Load Layouts**: Instantly restore saved window arrangements
- **⌨️ Global Keyboard Shortcuts**: Assign custom hotkeys to quickly switch between layouts
- **🎯 Smart Menu Interface**: Dynamic menu labels and intuitive controls
- **🔄 Replace & Rename**: Update existing layouts or give them custom names
- **⚙️ Settings Integration**: Launch at login, apply to all monitors, and more
- **🌟 macOS 26 Ready**: Optimized for the latest macOS features and Liquid Glass design

## 📦 Installation

### Option 1: DMG Installer (Recommended)
1. Download `Snap-WindowManager.dmg`
2. Double-click the DMG file to mount it
3. Drag the Snap app to your Applications folder
4. Launch Snap from Applications or Spotlight

### Option 2: PKG Installer
1. Download `Snap-WindowManager.pkg`
2. Double-click the PKG file to run the installer
3. Follow the installation wizard
4. Launch Snap from Applications or Spotlight

## 🚀 Usage

### Basic Operations

1. **💾 Save Layout**: Click the Snap menu bar icon → "Save layout"
2. **⚡ Load Layout**: Click the Snap menu bar icon → Select a saved layout → "Load layout"
3. **⌨️ Record Shortcut**: Click the Snap menu bar icon → Select a layout → "Record shortcut"

### 🎯 Advanced Features

- **🔄 Replace Layout**: Update an existing layout with current window arrangement
- **✏️ Rename Layout**: Give your layouts custom names
- **🗑️ Delete Layout**: Remove layouts you no longer need
- **⭐ Favorite Toggle**: Mark layouts as favorites for quick access

### ⌨️ Keyboard Shortcuts

- Assign custom keyboard shortcuts to your layouts for instant switching
- Use any combination of ⌘, ⌥, ⌃, ⇧ modifiers
- Shortcuts work globally across all applications
- Visual feedback shows assigned shortcuts in the menu

### 🎨 Dynamic Icon Features

- **🌓 Light/Dark Mode**: Icon automatically adapts to system appearance
- **✨ Translucent Effects**: Beautiful blur materials and translucency
- **🎨 Blue Gradient**: Professional gradient design from Icon Composer
- **📱 Dynamic Scaling**: Optimized for all icon sizes and contexts
- **⚡ State Indicators**: Icon changes during layout operations

### 🎯 Menu Features

- **🧠 Smart Labels**: Menu shows "Record shortcut" or "Update shortcut" based on current state
- **🔒 Persistent Menu**: Menu stays open for management actions, closes only for "Load" or "Quit"
- **👁️ Visual Feedback**: See shortcuts displayed next to layout names
- **📋 Direct Access**: Saved layouts visible in main menu without submenus

## 📋 System Requirements

- **macOS**: 14.0 (Sonoma) or later (optimized for macOS 26)
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel
- **Permissions**: 
  - Accessibility permissions (required for window management)
  - Screen recording permissions (required for layout capture)

## 🔐 Permissions

On first launch, Snap will request:
- **♿ Accessibility Access**: Required to move and resize windows
- **📹 Screen Recording Access**: Required to capture window positions

Grant these permissions in **System Preferences** → **Security & Privacy** → **Privacy**.

### 🔧 Manual Permission Setup
If automatic permission requests don't appear:
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** and add Snap
3. Select **Screen Recording** and add Snap
4. Restart Snap after granting permissions

## 🔧 Troubleshooting

### 🚀 Launch at Login Issues
If automatic login item setup fails (common in sandboxed environments):
1. Go to **System Preferences** → **Users & Groups** → **Login Items**
2. Click the "+" button and add Snap manually

### ⌨️ Shortcuts Not Working
- Ensure Snap has Accessibility permissions
- Check that the shortcut isn't already used by another application
- Try recording the shortcut again
- Restart Snap after granting permissions

### 📱 Layout Not Loading
- Verify the applications are still running
- Some applications may not support window positioning
- Try saving and loading the layout again
- Check that applications haven't changed their window structure

### 🎨 Icon Not Displaying
- The dynamic icon should appear automatically
- If icon looks distorted, try restarting Snap
- Icon adapts to light/dark mode automatically

### 🔄 Menu Not Updating
- Menu should stay open for management actions
- Only closes for "Load layout" or "Quit"
- Try clicking the menu bar icon again if it disappears

## 🎯 Tips & Best Practices

### 💡 Productivity Tips
- **Create Layout Sets**: Save different layouts for different workflows (coding, design, research)
- **Use Descriptive Names**: Name your layouts clearly (e.g., "Coding Setup", "Design Mode")
- **Assign Logical Shortcuts**: Use consistent modifier keys (e.g., ⌘⌥1, ⌘⌥2 for layouts)
- **Test Layouts**: Verify layouts work before relying on them for important work

### 🎨 Icon Customization
- The dynamic icon automatically adapts to your system appearance
- No manual configuration needed - it works out of the box
- Icon shows processing states during layout operations

## 📞 Support

For issues or feature requests, please contact the developer.

## 📝 Version History

- **1.0.0**: Initial release with core window management features
  - Save, load, replace, rename, and delete layouts
  - Global keyboard shortcuts
  - Smart menu interface
  - Settings integration
  - Dynamic Icon Composer integration
  - macOS 26 Liquid Glass design support

## 🏗️ Technical Details

- **Framework**: SwiftUI + AppKit
- **Icon Design**: Icon Composer with dynamic properties
- **Architecture**: Menu bar application with global hotkey support
- **Data Storage**: UserDefaults with property list compatibility
- **Permissions**: Accessibility API for window management

---

**Snap** - Organize your windows, boost your productivity. 🚀✨