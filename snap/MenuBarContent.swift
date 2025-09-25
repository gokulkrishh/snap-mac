import SwiftUI

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
                    Task { await manager.loadLayout(name: name) }
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
                    Menu(name) {
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