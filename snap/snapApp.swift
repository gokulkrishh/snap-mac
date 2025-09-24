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
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }

        var layoutData: [[String: Any]] = []
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
                layoutData.append(layout)
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
