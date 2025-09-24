//
//  snapApp.swift
//  snap
//
//  Created by Gokulakrishnan Kalaikovan on 24/09/25.
//

import SwiftUI
import CoreGraphics
import ApplicationServices
import Combine
import AppKit

@main
struct SnapApp: App {
    @StateObject private var manager = LayoutManager()

    var body: some Scene {
        MenuBarExtra("Snap", systemImage: "macwindow") {
            MenuBarContent(manager: manager)
        }
    }
}

class LayoutManager: ObservableObject {
    @Published var layouts: [String: NSDictionary] = [:]
    private var globalMonitor: Any?

    init() {
        loadLayouts()
        setupGlobalHotkeys()
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupGlobalHotkeys() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = Int(event.keyCode)

            // Check if this matches any layout shortcut
            for (name, layoutDict) in self.layouts {
                if let shortcut = layoutDict["shortcut"] as? [String: Any],
                   let storedKeyCode = shortcut["keyCode"] as? Int,
                   let storedModifiers = shortcut["modifiers"] as? Int,
                   keyCode == storedKeyCode && modifiers.rawValue == storedModifiers {
                    // Load this layout
                    self.loadLayout(name: name)
                    break
                }
            }
        }
    }

    private func loadLayouts() {
        self.layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
    }

    func saveLayout() {
        // Request screen recording permission if not granted
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            // Wait a bit for the user to grant
            sleep(2)
        }

        let options: CGWindowListOption = .optionOnScreenOnly // Only on-screen windows
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var layoutData: [[String: Any]] = []

        // Get all running applications for bundle ids
        let apps = NSWorkspace.shared.runningApplications

        // System processes that shouldn't be included in layouts
        let systemProcesses = ["Window Server", "Dock", "Finder", "SystemUIServer", "loginwindow"]
        // Also exclude the Snap app itself since it's a menu bar app with no accessible windows
        _ = systemProcesses + ["snap"]

        for window in windowList {
            if let bounds = window[kCGWindowBounds as String] as? NSDictionary,
               let ownerName = window[kCGWindowOwnerName as String] as? String,
               let name = window[kCGWindowName as String] as? String,
               let windowID = window[kCGWindowNumber as String] as? NSNumber {

                // Skip system processes, UI elements, and the app itself
                let obviousSystem = ["Window Server", "Dock", "Finder", "SystemUIServer", "loginwindow", "Control Centre", "Notification Centre", "System Settings", "Menu Bar", "Wallpaper", "snap"]
                if !obviousSystem.contains(ownerName),
                   let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber {
                    // Get bundle identifier for reopening if needed
                    let app = apps.first(where: { $0.processIdentifier == ownerPID.intValue })
                    let bundleId = app?.bundleIdentifier ?? ""
                    let layout: [String: Any] = [
                        "owner": ownerName,
                        "name": name,
                        "bounds": bounds,
                        "id": windowID.intValue,
                        "bundleId": bundleId,
                        "shortcut": NSNull()
                    ]
                    layoutData.append(layout)
                }
            }
        }

        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        let name = "Layout \(savedLayouts.count + 1)"
        if let data = try? JSONSerialization.data(withJSONObject: layoutData) {
            let layoutDict: NSDictionary = ["data": data, "date": Date()]
            savedLayouts[name] = layoutDict
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            self.layouts = savedLayouts
        }
    }

    func toggleFavorite(name: String) {
        if var dict = layouts[name] as? [String: Any] {
            let currentFav = dict["favorite"] as? Bool ?? false
            dict["favorite"] = !currentFav
            let newDict = NSDictionary(dictionary: dict)
            var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
            savedLayouts[name] = newDict
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            self.layouts = savedLayouts
        }
    }

    func loadLayout(name: String) {
        if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            if !AXIsProcessTrustedWithOptions(options) {
                return
            }
        }

        guard let layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary],
              let layoutDict = layouts[name],
              let data = layoutDict["data"] as? Data,
              let savedLayouts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        // Filter out system processes, UI elements, and excluded apps when loading (for backward compatibility)
        let systemProcesses = ["Window Server", "Dock", "Finder", "SystemUIServer", "loginwindow", "Control Centre", "Notification Centre", "System Settings", "Menu Bar", "Wallpaper"]
        let excludedApps = systemProcesses + ["snap"] // Exclude Snap app since it's a menu bar app
        let filteredLayouts = savedLayouts.filter { saved in
            if let owner = saved["owner"] as? String {
                return !excludedApps.contains(owner)
            }
            return false
        }

        // Use Accessibility API for window manipulation - more reliable than AppleScript
        for saved in filteredLayouts {
            guard let savedOwner = saved["owner"] as? String,
                  let savedName = saved["name"] as? String,
                  let bounds = saved["bounds"] as? [String: Any],
                  let x = bounds["X"] as? Double,
                  let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double,
                  let height = bounds["Height"] as? Double else {
                continue
            }

            // Find the running application
            let apps = NSWorkspace.shared.runningApplications
            var app = apps.first(where: { $0.localizedName == savedOwner })

            // If app not running, try to open it
            if app == nil, let bundleId = saved["bundleId"] as? String, !bundleId.isEmpty,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                // Wait a bit for the app to launch
                sleep(5)
                // Refresh running apps
                let updatedApps = NSWorkspace.shared.runningApplications
                app = updatedApps.first(where: { $0.localizedName == savedOwner })
            }

            guard let app = app else {
                continue
            }

            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)

            // Get the windows
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            guard result == AXError.success else {
                continue
            }

            let windows = value as! CFArray

            // Find the window with matching name
            for i in 0..<CFArrayGetCount(windows) {
                let window = CFArrayGetValueAtIndex(windows, i)
                let windowElement = unsafeBitCast(window, to: AXUIElement.self)

                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &title)
                let windowTitle = title as? String ?? ""

                if windowTitle == savedName || (savedName.isEmpty && windowTitle.isEmpty) {
                    // Set position
                    var position = CGPoint(x: x, y: y)
                    let posValue = AXValueCreate(.cgPoint, &position)
                    let posResult = AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posValue!)
                    if posResult != AXError.success {
                        continue
                    }

                    // Set size
                    var size = CGSize(width: width, height: height)
                    let sizeValue = AXValueCreate(.cgSize, &size)
                    let sizeResult = AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue!)
                    if sizeResult != AXError.success {
                        continue
                    }

                    break
                }
            }
        }
    }

    func deleteLayout(name: String) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        savedLayouts.removeValue(forKey: name)
        UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        self.layouts = savedLayouts
    }
}

struct MenuBarContent: View {
    @StateObject var manager: LayoutManager

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
            Menu(name) {
                Button("Load Layout") {
                    manager.loadLayout(name: name)
                }
                Button("Remove from Favourites") {
                    manager.toggleFavorite(name: name)
                }
                Divider()
                Button("Delete Layout") {
                    manager.deleteLayout(name: name)
                }
            }
        }

        if !favorites.isEmpty {
            Divider()
        }

        Button("Save Layout") {
            manager.saveLayout()
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
                    Menu(name) {
                        Button("Load Layout") {
                            manager.loadLayout(name: name)
                        }
                        Button(favorite ? "Remove from Favourites" : "Add to Favourites") {
                            manager.toggleFavorite(name: name)
                        }
                        Divider()
                        Button("Delete Layout") {
                            manager.deleteLayout(name: name)
                        }
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

struct SettingsView: View {
    @ObservedObject var manager: LayoutManager
    @State private var selectedLayout: String?
    @State private var recordingShortcut: Bool = false
    @State private var currentShortcut: [String: Any]?
    @State private var refreshTrigger = false

    private func openEditWindow(for layoutName: String) {
        if let layoutDict = manager.layouts[layoutName],
           let data = layoutDict["data"] as? Data,
           let apps = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let layout: [String: Any] = ["name": layoutName, "apps": apps]
            let editView = EditLayoutView(layout: layout, manager: manager)
            let hostingController = NSHostingController(rootView: editView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Edit Layout: \(layoutName)"
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()
            window.makeKeyAndOrderFront(nil as Any?)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startRecordingShortcut(for layoutName: String) {
        recordingShortcut = true
        currentShortcut = nil

        // Open a small recording window
        var recordingWindow: NSWindow?
        let recordView = ShortcutRecorderView { shortcut in
            self.recordingShortcut = false
            if let shortcut = shortcut {
                self.saveShortcut(for: layoutName, shortcut: shortcut)
                // Force UI refresh
                self.refreshTrigger.toggle()
            }
            // Close the window after processing
            recordingWindow?.close()
        }
        let hostingController = NSHostingController(rootView: recordView)
        recordingWindow = NSWindow(contentViewController: hostingController)
        recordingWindow!.title = "Record Shortcut for \(layoutName)"
        recordingWindow!.setContentSize(NSSize(width: 300, height: 100))
        recordingWindow!.center()
        recordingWindow!.makeKeyAndOrderFront(nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveShortcut(for layoutName: String, shortcut: [String: Any]) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]

        if var layoutDict = savedLayouts[layoutName] as? [String: Any] {
            layoutDict["shortcut"] = shortcut
            savedLayouts[layoutName] = NSDictionary(dictionary: layoutDict)
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            // Force UI update by creating a new dictionary reference
            manager.layouts = savedLayouts
        }
    }

    private func getShortcutString(for layoutName: String) -> String {
        if let layoutDict = manager.layouts[layoutName],
           let shortcut = layoutDict["shortcut"] as? [String: Any],
           let keyCode = shortcut["keyCode"] as? Int,
           let modifiers = shortcut["modifiers"] as? Int {
            return shortcutDescription(keyCode: keyCode, modifiers: modifiers)
        }
        return "None"
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

    var body: some View {
        VStack(spacing: 20) {
            Text("Snap Settings")
                .font(.title)
                .padding(.top)

            // Layout Management
            VStack(alignment: .leading, spacing: 10) {
                Text("Saved Layouts")
                    .font(.headline)

                List(manager.layouts.keys.sorted(), id: \.self, selection: $selectedLayout) { name in
                    Text(name)
                }
                .frame(height: 150)

                HStack {
                    if let selected = selectedLayout {
                        Button("Edit Layout") {
                            openEditWindow(for: selected)
                        }
                        Button("Delete Layout") {
                            manager.deleteLayout(name: selected)
                            selectedLayout = nil
                        }
                    }
                    Spacer()
                    if let selected = selectedLayout {
                        VStack(alignment: .trailing) {
                            Text("Shortcut: \(getShortcutString(for: selected))")
                                .font(.caption)
                            Button("Record Shortcut") {
                                startRecordingShortcut(for: selected)
                            }
                        }
                    }
                    Button("Delete All Layouts") {
                        manager.layouts.removeAll()
                        UserDefaults.standard.removeObject(forKey: "layouts")
                        selectedLayout = nil
                    }
                    .foregroundColor(.red)
                }
            }

            // Keyboard Shortcuts (placeholder)
            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard Shortcuts")
                    .font(.headline)

                Text("Coming soon: Record shortcuts for Save/Load")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(width: 400, height: 500)
        .padding()
    }
}

struct ShortcutRecorderView: View {
    let onShortcutRecorded: ([String: Any]?) -> Void
    @State private var recordedShortcut: String = "Press shortcut..."

    init(onShortcutRecorded: @escaping ([String: Any]?) -> Void) {
        self.onShortcutRecorded = onShortcutRecorded
    }

    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 20) {
            Text("Press your desired shortcut")
                .font(.headline)
            Text(recordedShortcut)
                .font(.title)
                .foregroundColor(.blue)
            HStack {
                Button("Cancel") {
                    onShortcutRecorded(nil)
                    // Don't close window here - let the completion handler handle it
                }
                Spacer()
                Button("Clear") {
                    recordedShortcut = "Press shortcut..."
                }
            }
        }
        .frame(width: 250, height: 120)
        .padding()
        .onAppear {
            startMonitoringKeys()
        }
        .onDisappear {
            stopMonitoringKeys()
        }
    }

    private func startMonitoringKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = Int(event.keyCode)

            // Require at least one modifier
            if modifiers.isEmpty {
                return event
            }

            let shortcut: [String: Any] = [
                "keyCode": keyCode,
                "modifiers": modifiers.rawValue
            ]

            // Format display
            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }

            let key = keyName(for: keyCode)
            parts.append(key)
            recordedShortcut = parts.joined(separator: "")

            // Stop monitoring after recording
            stopMonitoringKeys()

            // Call completion after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onShortcutRecorded(shortcut)
                // Window will be closed by the completion handler
            }

            return nil // Consume the event
        }
    }

    private func stopMonitoringKeys() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func keyName(for keyCode: Int) -> String {
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
}

struct EditLayoutView: View {
    let layout: [String: Any]
    @ObservedObject var manager: LayoutManager
    @State private var apps: [[String: Any]]

    init(layout: [String: Any], manager: LayoutManager) {
        self.layout = layout
        self.manager = manager
        self._apps = State(initialValue: layout["apps"] as? [[String: Any]] ?? [])
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Layout: \(layout["name"] as? String ?? "")")
                .font(.title)

            List {
                ForEach(apps.indices, id: \.self) { index in
                    HStack {
                        Text(apps[index]["owner"] as? String ?? "")
                        Text("-")
                        Text(apps[index]["name"] as? String ?? "")
                        Spacer()
                        Button("Remove") {
                            apps.remove(at: index)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .frame(height: 200)

            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                Spacer()
                Button("Save Changes") {
                    saveEditedLayout()
                    closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 500, height: 400)
        .padding()
    }

    private func saveEditedLayout() {
        guard let name = layout["name"] as? String else { return }
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        if let data = try? JSONSerialization.data(withJSONObject: apps) {
            let layoutDict: NSDictionary = ["data": data, "date": Date()]
            savedLayouts[name] = layoutDict
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            manager.layouts = savedLayouts
        }
    }
}
