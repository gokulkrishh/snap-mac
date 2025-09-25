import SwiftUI
import CoreGraphics
import ApplicationServices
import Combine
import AppKit

@MainActor
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
                    Task { await self.loadLayout(name: name) }
                    break
                }
            }
        }
    }

    private func loadLayouts() {
        DispatchQueue.main.async {
            self.layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        }
    }
    
    func getSortedLayoutNames() -> [String] {
        return layouts.compactMap { (name, layoutDict) -> (String, Date)? in
            guard let dict = layoutDict as? [String: Any],
                  let date = dict["date"] as? Date else { return nil }
            return (name, date)
        }.sorted { $0.1 < $1.1 }.map { $0.0 }
    }
    
    func getSortedFavoriteLayoutNames() -> [String] {
        return layouts.compactMap { (name, layoutDict) -> (String, Date)? in
            guard let dict = layoutDict as? [String: Any],
                  let isFavorite = dict["favorite"] as? Bool,
                  isFavorite,
                  let date = dict["date"] as? Date else { return nil }
            return (name, date)
        }.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    func saveLayout() async {
        await saveLayoutWithName(nil)
    }
    
    func replaceLayout(name: String) async {
        await saveLayoutWithName(name)
    }
    
    private func saveLayoutWithName(_ layoutName: String?) async {
        // Request screen recording permission if not granted
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            // Wait a bit for the user to grant
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
        
        let name: String
        if let layoutName = layoutName {
            // Replace existing layout
            name = layoutName
            // Preserve existing shortcut and favorite status
            if let existingLayout = savedLayouts[layoutName] as? [String: Any] {
                let layoutDict: NSDictionary = [
                    "data": try! JSONSerialization.data(withJSONObject: layoutData),
                    "date": Date(),
                    "shortcut": existingLayout["shortcut"] ?? NSNull(),
                    "favorite": existingLayout["favorite"] ?? false
                ]
                savedLayouts[name] = layoutDict
            } else {
                let layoutDict: NSDictionary = ["data": try! JSONSerialization.data(withJSONObject: layoutData), "date": Date()]
                savedLayouts[name] = layoutDict
            }
        } else {
            // Create new layout
            name = "Layout \(savedLayouts.count + 1)"
            let layoutDict: NSDictionary = ["data": try! JSONSerialization.data(withJSONObject: layoutData), "date": Date()]
            savedLayouts[name] = layoutDict
        }
        
        UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        DispatchQueue.main.async {
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
            DispatchQueue.main.async {
                self.layouts = savedLayouts
            }
        }
    }

    func loadLayout(name: String) async {
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
                try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                // Wait a bit for the app to launch
                try? await Task.sleep(nanoseconds: 5_000_000_000)
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
        DispatchQueue.main.async {
            self.layouts = savedLayouts
        }
    }
    
    func renameLayout(from oldName: String, to newName: String) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        
        // Check if new name already exists
        if savedLayouts[newName] != nil {
            return // Don't rename if new name already exists
        }
        
        // Get the old layout data
        if let oldLayout = savedLayouts[oldName] {
            // Remove old layout and add with new name
            savedLayouts.removeValue(forKey: oldName)
            savedLayouts[newName] = oldLayout
            
            // Save to UserDefaults
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.layouts = savedLayouts
            }
        }
    }
    
    func setShortcut(for layoutName: String, shortcut: String?) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        
        if var layoutDict = savedLayouts[layoutName] as? [String: Any] {
            if let shortcut = shortcut {
                layoutDict["shortcut"] = shortcut
            } else {
                layoutDict.removeValue(forKey: "shortcut")
            }
            savedLayouts[layoutName] = layoutDict as NSDictionary
            
            // Save to UserDefaults
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.layouts = savedLayouts
            }
        }
    }
}