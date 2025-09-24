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
    var body: some Scene {
        MenuBarExtra("Snap", systemImage: "macwindow") {
            MenuBarContent()
        }
    }
}

class LayoutManager: ObservableObject {
    @Published var layouts: [String: NSDictionary] = [:]

    init() {
        loadLayouts()
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

                // Skip system processes and the app itself
                let obviousSystem = ["Window Server", "Dock", "snap"]
                if !obviousSystem.contains(ownerName) {
                    // Get bundle identifier for reopening if needed
                    let bundleId = apps.first(where: { $0.localizedName == ownerName })?.bundleIdentifier ?? ""
                    let layout: [String: Any] = [
                        "owner": ownerName,
                        "name": name,
                        "bounds": bounds,
                        "id": windowID.intValue,
                        "bundleId": bundleId
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

        // Filter out system processes and excluded apps when loading (for backward compatibility)
        let systemProcesses = ["Window Server", "Dock", "Finder", "SystemUIServer", "loginwindow"]
        let excludedApps = systemProcesses + ["snap"] // Exclude Snap app since it's a menu bar app
        let filteredLayouts = savedLayouts.filter { saved in
            if let owner = saved["owner"] as? String {
                return !excludedApps.contains(owner)
            }
            return false
        }

        // Use Accessibility API for window manipulation - more reliable than AppleScript
        for saved in filteredLayouts {
            if let savedOwner = saved["owner"] as? String,
               let savedName = saved["name"] as? String,
               let bounds = saved["bounds"] as? [String: Any],
               let x = bounds["X"] as? Double,
               let y = bounds["Y"] as? Double,
               let width = bounds["Width"] as? Double,
               let height = bounds["Height"] as? Double {

                // Find the running application
                let apps = NSWorkspace.shared.runningApplications
                var app = apps.first(where: { $0.localizedName == savedOwner })

                // If app not running, try to open it
                if app == nil, let bundleId = saved["bundleId"] as? String, !bundleId.isEmpty,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    do {
                        try NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        // Wait a bit for the app to launch
                        sleep(3)
                        // Refresh running apps
                        let updatedApps = NSWorkspace.shared.runningApplications
                        app = updatedApps.first(where: { $0.localizedName == savedOwner })
                    } catch {
                        // Failed to open
                    }
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
    }

    func deleteLayout(name: String) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        savedLayouts.removeValue(forKey: name)
        UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        self.layouts = savedLayouts
    }
}

struct MenuBarContent: View {
    @StateObject private var manager = LayoutManager()

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
            // TODO: open settings window
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
