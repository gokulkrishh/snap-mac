//
//  snapApp.swift
//  snap
//
//  Created by Gokulakrishnan Kalaikovan on 24/09/25.
//

import SwiftUI

@main
struct SnapApp: App {
    var body: some Scene {
        MenuBarExtra("Snap", systemImage: "macwindow") {
            MenuBarContent()
        }
    }
}

struct MenuBarContent: View {
    @AppStorage("layoutDummy") private var dummy = 0

    var body: some View {
        Button("Save Layout") {
            saveLayout()
            dummy += 1
        }

        let layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: Data] ?? [:]
        Menu("Saved Layouts") {
            if layouts.isEmpty {
                Text("No saved layouts")
            } else {
                ForEach(layouts.keys.sorted(), id: \.self) { name in
                    Button(name) {
                        loadLayout(name: name)
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

    func saveLayout() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }

        var layouts: [[String: Any]] = []
        for window in windowList {
            if let bounds = window[kCGWindowBounds as String] as? NSDictionary,
               let ownerName = window[kCGWindowOwnerName as String] as? String,
               let name = window[kCGWindowName as String] as? String,
               let windowID = window[kCGWindowNumber as String] as? NSNumber {
                let layout: [String: Any] = [
                    "owner": ownerName,
                    "name": name,
                    "bounds": bounds,
                    "id": windowID.intValue
                ]
                layouts.append(layout)
            }
        }

        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: Data] ?? [:]
        let name = "Layout \(savedLayouts.count + 1)"
        if let data = try? JSONSerialization.data(withJSONObject: layouts) {
            savedLayouts[name] = data
            UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        }
    }

    func loadLayout(name: String) {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            return
        }

        guard let layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: Data],
              let data = layouts[name],
              let savedLayouts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(system, kAXWindowsAttribute as CFString, &value)

        guard let windows = value as? [AXUIElement] else { return }

        for window in windows {
            var appElement: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &appElement)
            guard let app = appElement else { continue }

            var appName: CFTypeRef?
            AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appName)

            var windowName: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowName)

            guard let ownerName = appName as? String,
                  let nameStr = windowName as? String else { continue }

            for saved in savedLayouts {
                if let savedOwner = saved["owner"] as? String,
                   let savedName = saved["name"] as? String,
                   savedOwner == ownerName,
                   savedName == nameStr,
                   let bounds = saved["bounds"] as? [String: Any],
                   let x = bounds["X"] as? Double,
                   let y = bounds["Y"] as? Double,
                   let width = bounds["Width"] as? Double,
                   let height = bounds["Height"] as? Double {

                    let position = CGPoint(x: x, y: y)
                    let size = CGSize(width: width, height: height)

                    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position as CFTypeRef)
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size as CFTypeRef)
                }
            }
        }
    }
}
