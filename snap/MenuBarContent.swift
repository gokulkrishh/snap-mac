import SwiftUI
import AppKit

struct MenuBarContent: View {
    @StateObject var manager: LayoutManager

    private func getShortcutString(for layoutName: String) -> String {
        if let layoutDict = manager.layouts[layoutName],
           let shortcut = layoutDict["shortcut"] as? [String: Any],
           let keyCode = shortcut["keyCode"] as? Int,
           let modifiers = shortcut["modifiers"] as? Int {
            return shortcutDescription(keyCode: keyCode, modifiers: modifiers)
        }
        return ""
    }

    private func shortcutDescription(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []
        if UInt(modifiers) & NSEvent.ModifierFlags.command.rawValue != 0 { parts.append("⌘") }
        if UInt(modifiers) & NSEvent.ModifierFlags.shift.rawValue != 0 { parts.append("⇧") }
        if UInt(modifiers) & NSEvent.ModifierFlags.option.rawValue != 0 { parts.append("⌥") }
        if UInt(modifiers) & NSEvent.ModifierFlags.control.rawValue != 0 { parts.append("⌃") }

        let key = keyName(for: keyCode)
        parts.append(key)
        return parts.joined(separator: "")
    }

    private func keyName(for keyCode: Int) -> String {
        // Simple mapping for common keys
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        case 65: return "."
        case 67: return "*"
        case 69: return "+"
        case 71: return "Clear"
        case 75: return "/"
        case 76: return "Enter"
        case 78: return "-"
        case 81: return "="
        case 82: return "0"
        case 83: return "1"
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 54: return "⇧"
        case 55: return "⌘"
        case 56: return "⇧"
        case 57: return "⇪"
        case 58: return "⌥"
        case 59: return "⌃"
        case 60: return "⇧"
        case 61: return "⌥"
        case 62: return "⌃"
        default: return "Key\(keyCode)"
        }
    }


    private func openSettings() {
        let settingsView = SettingsView(manager: manager)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Snap Settings"
        window.setContentSize(NSSize(width: 400, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some View {
        let favorites = manager.layouts.filter { ($0.value["favorite"] as? Bool) == true }.sorted { ($0.value["date"] as? Date ?? Date.distantPast) > ($1.value["date"] as? Date ?? Date.distantPast) }

        if !favorites.isEmpty {
            Button("Favourites", action: {}).disabled(true)
        }
        ForEach(favorites, id: \.key) { name, _ in
            let shortcut = getShortcutString(for: name)
            Menu {
                Button("Load Layout") {
                    Task { await manager.loadLayout(name: name) }
                }
                Button("Remove from Favourites") {
                    manager.toggleFavorite(name: name)
                }
                Divider()
                Button("Delete Layout") {
                    manager.deleteLayout(name: name)
                }
            } label: {
                StyledMenuLabel(name: name, shortcut: shortcut)
            }
        }

        if !favorites.isEmpty {
            Divider()
        }

        Button("Save Layout") {
            Task { await manager.saveLayout() }
        }

        let allLayouts = manager.layouts.sorted {
            let fav1 = $0.value["favorite"] as? Bool ?? false
            let fav2 = $1.value["favorite"] as? Bool ?? false
            if fav1 != fav2 { return fav1 && !fav2 }
            let date1 = $0.value["date"] as? Date ?? Date.distantPast
            let date2 = $1.value["date"] as? Date ?? Date.distantPast
            return date1 > date2
        }
        Menu("Saved Layouts") {
            if allLayouts.isEmpty {
                Text("No saved layouts")
            } else {
                ForEach(allLayouts, id: \.key) { name, dict in
                    let favorite = dict["favorite"] as? Bool ?? false
                    let shortcut = getShortcutString(for: name)
                    Menu {
                        Button("Load Layout") {
                            Task { await manager.loadLayout(name: name) }
                        }
                        Button(favorite ? "Remove from Favourites" : "Add to Favourites") {
                            manager.toggleFavorite(name: name)
                        }
                        Divider()
                        Button("Delete Layout") {
                            manager.deleteLayout(name: name)
                        }
                    } label: {
                        StyledMenuLabel(name: name, shortcut: shortcut)
                    }
                }
            }
        }

        Divider()

        Button("Settings") {
            openSettings()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct StyledMenuLabel: View {
    let name: String
    let shortcut: String
    
    var body: some View {
        Text(createStyledText())
    }
    
    private func createStyledText() -> String {
        if shortcut.isEmpty {
            return name
        } else {
            // Use tab character for proper macOS menu alignment
            return "\(name)\t\(shortcut)"
        }
    }
}

