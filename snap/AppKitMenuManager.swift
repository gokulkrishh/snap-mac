import AppKit
import SwiftUI
import Combine

class AppKitMenuManager: ObservableObject {
    @Published var layouts: [String: NSDictionary] = [:]
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let layoutManager = LayoutManager()
    
    init() {
        loadLayouts()
        setupMenuBar()
        observeLayoutManager()
    }
    
    private func loadLayouts() {
        self.layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
    }
    
    private func observeLayoutManager() {
        // Observe LayoutManager's layouts property changes
        layoutManager.$layouts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLayouts in
                DispatchQueue.main.async {
                    self?.layouts = newLayouts
                    self?.refreshMenu()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "Snap")
            button.action = #selector(menuBarButtonClicked)
            button.target = self
        }
        
        createMenu()
    }
    
    @objc private func menuBarButtonClicked() {
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    private func createMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false
        
        // Favorites section
        let favorites = layouts.filter { ($0.value["favorite"] as? Bool) == true }
            .sorted { ($0.value["date"] as? Date ?? Date.distantPast) < ($1.value["date"] as? Date ?? Date.distantPast) }
        
        if !favorites.isEmpty {
            let favoritesHeader = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
            favoritesHeader.isEnabled = false
            menu?.addItem(favoritesHeader)
            
            for (name, _) in favorites {
                addLayoutMenuItem(name: name, to: menu!)
            }
            
            menu?.addItem(NSMenuItem.separator())
        }
        
        // Save Layout
        let saveItem = NSMenuItem(title: "Save Layout", action: #selector(saveLayout), keyEquivalent: "")
        saveItem.target = self
        menu?.addItem(saveItem)
        
        // Saved Layouts submenu
        let savedLayoutsItem = NSMenuItem(title: "Saved Layouts", action: nil, keyEquivalent: "")
        let savedLayoutsMenu = NSMenu()
        
        let allLayouts = layouts.sorted {
            let fav1 = $0.value["favorite"] as? Bool ?? false
            let fav2 = $1.value["favorite"] as? Bool ?? false
            if fav1 != fav2 { return fav1 && !fav2 }
            let date1 = $0.value["date"] as? Date ?? Date.distantPast
            let date2 = $1.value["date"] as? Date ?? Date.distantPast
            return date1 < date2
        }
        
        if allLayouts.isEmpty {
            let emptyItem = NSMenuItem(title: "No saved layouts", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            savedLayoutsMenu.addItem(emptyItem)
        } else {
            for (name, _) in allLayouts {
                addLayoutMenuItem(name: name, to: savedLayoutsMenu)
            }
        }
        
        savedLayoutsItem.submenu = savedLayoutsMenu
        menu?.addItem(savedLayoutsItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }
    
    private func addLayoutMenuItem(name: String, to menu: NSMenu) {
        let shortcut = getShortcutString(for: name)
        let menuItem = createStyledMenuItem(title: name, shortcut: shortcut)
        
        // Create submenu for layout actions
        let submenu = NSMenu()
        
        let loadItem = NSMenuItem(title: "Load Layout", action: #selector(loadLayout(_:)), keyEquivalent: "")
        loadItem.target = self
        loadItem.representedObject = name
        submenu.addItem(loadItem)
        
        let replaceItem = NSMenuItem(title: "Replace Layout", action: #selector(replaceLayout(_:)), keyEquivalent: "")
        replaceItem.target = self
        replaceItem.representedObject = name
        submenu.addItem(replaceItem)
        
        let favorite = layouts[name]?["favorite"] as? Bool ?? false
        let favoriteItem = NSMenuItem(
            title: favorite ? "Remove from Favourites" : "Add to Favourites",
            action: #selector(toggleFavorite(_:)),
            keyEquivalent: ""
        )
        favoriteItem.target = self
        favoriteItem.representedObject = name
        submenu.addItem(favoriteItem)
        
        submenu.addItem(NSMenuItem.separator())
        
        let deleteItem = NSMenuItem(title: "Delete Layout", action: #selector(deleteLayout(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = name
        submenu.addItem(deleteItem)
        
        menuItem.submenu = submenu
        menu.addItem(menuItem)
    }
    
    private func createStyledMenuItem(title: String, shortcut: String) -> NSMenuItem {
        let menuItem = NSMenuItem()
        
        if shortcut.isEmpty {
            menuItem.title = title
        } else {
            // Create NSAttributedString with proper styling
            let attributedTitle = NSMutableAttributedString()
            
            // Add the main title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
            attributedTitle.append(NSAttributedString(string: title, attributes: titleAttributes))
            
            // Add tab character for alignment
            attributedTitle.append(NSAttributedString(string: "\t"))
            
            // Add the shortcut with smaller, muted styling
            let shortcutAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            attributedTitle.append(NSAttributedString(string: shortcut, attributes: shortcutAttributes))
            
            menuItem.attributedTitle = attributedTitle
        }
        
        return menuItem
    }
    
    private func getShortcutString(for layoutName: String) -> String {
        if let layoutDict = layouts[layoutName],
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
    
    // MARK: - Actions
    
    @objc private func saveLayout() {
        Task { await layoutManager.saveLayout() }
    }
    
    @objc private func loadLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        Task { await layoutManager.loadLayout(name: layoutName) }
    }
    
    @objc private func replaceLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        Task { await layoutManager.replaceLayout(name: layoutName) }
    }
    
    @objc private func toggleFavorite(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        layoutManager.toggleFavorite(name: layoutName)
    }
    
    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        layoutManager.deleteLayout(name: layoutName)
    }
    
    @objc private func openSettings() {
        // Open settings window
        let settingsView = SettingsView(manager: layoutManager)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Snap Settings"
        window.setContentSize(NSSize(width: 400, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func refreshMenu() {
        createMenu()
        
        // Force menu update by reassigning it
        if let statusItem = statusItem {
            statusItem.menu = menu
        }
    }
}