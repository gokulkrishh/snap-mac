import AppKit
import SwiftUI
import Combine
import ServiceManagement

class AppKitMenuManager: ObservableObject {
    @Published var layouts: [String: NSDictionary] = [:]
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let layoutManager = LayoutManager()
    
    // Global hotkey monitoring
    private var registeredShortcuts: [String: (layoutName: String, eventMonitor: Any)] = [:]
    
    init() {
        loadLayouts()
        setupMenuBar()
        observeLayoutManager()
    }
    
    private func loadLayouts() {
        self.layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        updateGlobalShortcuts()
    }
    
    private func observeLayoutManager() {
        // Observe LayoutManager's layouts property changes
        layoutManager.$layouts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLayouts in
                DispatchQueue.main.async {
                    self?.layouts = newLayouts
                    self?.refreshMenu()
                    self?.updateGlobalShortcuts()
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
        
        // Save Layout
        let saveItem = NSMenuItem(title: "Save Layout", action: #selector(saveLayout), keyEquivalent: "")
        saveItem.target = self
        menu?.addItem(saveItem)
        
        // Saved Layouts submenu
        let savedLayoutsItem = NSMenuItem(title: "Saved Layouts", action: nil, keyEquivalent: "")
        let savedLayoutsMenu = NSMenu()
        
        let allLayouts = layouts.sorted {
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
        
        // Settings submenu
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        
        // Launch at Login
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = launchAtLogin ? .on : .off
        settingsMenu.addItem(launchItem)
        
        // Apply to All Monitors
        let applyToAllMonitors = UserDefaults.standard.bool(forKey: "applySameToAllMonitors")
        let monitorsItem = NSMenuItem(title: "Apply to All Monitors", action: #selector(toggleApplyToAllMonitors), keyEquivalent: "")
        monitorsItem.target = self
        monitorsItem.state = applyToAllMonitors ? .on : .off
        settingsMenu.addItem(monitorsItem)
        
        // Check for Updates
        let checkUpdates = UserDefaults.standard.bool(forKey: "checkUpdates")
        let updatesItem = NSMenuItem(title: "Check for Updates", action: #selector(toggleCheckUpdates), keyEquivalent: "")
        updatesItem.target = self
        updatesItem.state = checkUpdates ? .on : .off
        settingsMenu.addItem(updatesItem)
        
        settingsMenu.addItem(NSMenuItem.separator())
        
        // Delete All Layouts
        let deleteAllItem = NSMenuItem(title: "Delete All Layouts", action: #selector(deleteAllLayouts), keyEquivalent: "")
        deleteAllItem.target = self
        deleteAllItem.attributedTitle = NSAttributedString(
            string: "Delete All Layouts",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        settingsMenu.addItem(deleteAllItem)
        
        settingsItem.submenu = settingsMenu
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
        
        submenu.addItem(NSMenuItem.separator())
        
        let recordShortcutItem = NSMenuItem(title: "Record Shortcut", action: #selector(recordShortcut(_:)), keyEquivalent: "")
        recordShortcutItem.target = self
        recordShortcutItem.representedObject = name
        submenu.addItem(recordShortcutItem)
        
        submenu.addItem(NSMenuItem.separator())
        
        let renameItem = NSMenuItem(title: "Rename Layout", action: #selector(renameLayout(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = name
        submenu.addItem(renameItem)
        
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
           let shortcut = layoutDict["shortcut"] as? String {
            return shortcut
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
    
    @objc private func renameLayout(_ sender: NSMenuItem) {
        guard let oldName = sender.representedObject as? String else { return }
        
        // Show input dialog for new name
        let alert = NSAlert()
        alert.messageText = "Rename Layout"
        alert.informativeText = "Enter new name for '\(oldName)':"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = oldName
        inputField.placeholderString = "Layout name"
        alert.accessoryView = inputField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != oldName {
                layoutManager.renameLayout(from: oldName, to: newName)
            }
        }
    }
    
    @objc private func recordShortcut(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create a simple window for key capture
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 150),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Record Shortcut for '\(layoutName)'"
            window.center()
            window.level = .floating
            window.isReleasedWhenClosed = false
            
            // Create main view
            let mainView = NSView(frame: window.contentView!.bounds)
            window.contentView = mainView
            
            // Instruction label
            let instructionLabel = NSTextField(labelWithString: "Press the key combination:")
            instructionLabel.frame = NSRect(x: 20, y: 100, width: 310, height: 20)
            instructionLabel.font = NSFont.systemFont(ofSize: 14)
            instructionLabel.alignment = .center
            mainView.addSubview(instructionLabel)
            
            // Shortcut display field
            let shortcutField = NSTextField(frame: NSRect(x: 20, y: 50, width: 310, height: 30))
            shortcutField.stringValue = self.getShortcutString(for: layoutName)
            shortcutField.placeholderString = "Press keys..."
            shortcutField.isEditable = false
            shortcutField.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
            shortcutField.alignment = .center
            shortcutField.backgroundColor = NSColor.controlBackgroundColor
            shortcutField.isBordered = true
            mainView.addSubview(shortcutField)
            
            // Buttons with proper target/action setup
            let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearShortcutAction))
            clearButton.frame = NSRect(x: 20, y: 10, width: 80, height: 30)
            clearButton.bezelStyle = .rounded
            
            let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelShortcutAction))
            cancelButton.frame = NSRect(x: 120, y: 10, width: 80, height: 30)
            cancelButton.bezelStyle = .rounded
            
            let doneButton = NSButton(title: "Done", target: self, action: #selector(doneShortcutAction))
            doneButton.frame = NSRect(x: 220, y: 10, width: 80, height: 30)
            doneButton.bezelStyle = .rounded
            doneButton.keyEquivalent = "\r"
            
            
            // Store references
            self.currentShortcutWindow = window
            self.currentShortcutLayoutName = layoutName
            self.currentShortcutField = shortcutField
            
            // Add buttons first
            mainView.addSubview(clearButton)
            mainView.addSubview(cancelButton)
            mainView.addSubview(doneButton)
            
            // Create invisible key capture view that doesn't interfere with buttons
            let keyCaptureView = KeyCaptureView(frame: NSRect(x: 0, y: 40, width: 350, height: 110)) // Only cover top area
            keyCaptureView.onKeyCaptured = { [weak shortcutField] shortcut in
                DispatchQueue.main.async {
                    shortcutField?.stringValue = shortcut
                }
            }
            mainView.addSubview(keyCaptureView)
            
            // Show window and start capturing
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                keyCaptureView.startCapturing()
            }
        }
    }
    
    @objc private func clearShortcutAction(_ sender: Any) {
        guard let layoutName = currentShortcutLayoutName else { return }
        layoutManager.setShortcut(for: layoutName, shortcut: nil)
        currentShortcutWindow?.close()
        clearShortcutSession()
    }
    
    @objc private func cancelShortcutAction(_ sender: Any) {
        currentShortcutWindow?.close()
        clearShortcutSession()
    }
    
    @objc private func doneShortcutAction(_ sender: Any) {
        guard let layoutName = currentShortcutLayoutName,
              let shortcutField = currentShortcutField else { return }
        
        let shortcut = shortcutField.stringValue.isEmpty ? nil : shortcutField.stringValue
        layoutManager.setShortcut(for: layoutName, shortcut: shortcut)
        currentShortcutWindow?.close()
        clearShortcutSession()
    }
    
    private func clearShortcutSession() {
        currentShortcutWindow = nil
        currentShortcutLayoutName = nil
        currentShortcutField = nil
    }
    
    // Store current shortcut recording session
    private weak var currentShortcutWindow: NSWindow?
    private var currentShortcutLayoutName: String?
    private weak var currentShortcutField: NSTextField?
    
    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        layoutManager.deleteLayout(name: layoutName)
    }
    
    
    @objc private func toggleLaunchAtLogin() {
        let currentValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
        
        // Update login item
        let service = SMAppService.loginItem(identifier: "gokulkrishh.snap")
        do {
            if newValue {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
        
        refreshMenu()
    }
    
    @objc private func toggleApplyToAllMonitors() {
        let currentValue = UserDefaults.standard.bool(forKey: "applySameToAllMonitors")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "applySameToAllMonitors")
        refreshMenu()
    }
    
    @objc private func toggleCheckUpdates() {
        let currentValue = UserDefaults.standard.bool(forKey: "checkUpdates")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "checkUpdates")
        refreshMenu()
    }
    
    @objc private func deleteAllLayouts() {
        // Clear all layouts
        layoutManager.layouts.removeAll()
        UserDefaults.standard.removeObject(forKey: "layouts")
        refreshMenu()
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
    
    // MARK: - Global Shortcut Management
    
    private func updateGlobalShortcuts() {
        // Unregister all existing shortcuts
        unregisterAllShortcuts()
        
        // Register shortcuts for layouts that have them
        for (layoutName, layoutDict) in layouts {
            if let shortcutString = layoutDict["shortcut"] as? String, !shortcutString.isEmpty {
                registerGlobalShortcut(shortcutString, for: layoutName)
            }
        }
    }
    
    private func unregisterAllShortcuts() {
        for (_, (_, eventMonitor)) in registeredShortcuts {
            NSEvent.removeMonitor(eventMonitor)
        }
        registeredShortcuts.removeAll()
    }
    
    private func registerGlobalShortcut(_ shortcutString: String, for layoutName: String) {
        guard let (keyCode, modifiers) = parseShortcutString(shortcutString) else { return }
        
        let eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check if the key matches
            let keyMatches = event.keyCode == keyCode
            
            // Check if the relevant modifiers match (ignore caps lock, num lock, etc.)
            let relevantModifiers: UInt = NSEvent.ModifierFlags.command.rawValue | 
                                        NSEvent.ModifierFlags.option.rawValue | 
                                        NSEvent.ModifierFlags.control.rawValue | 
                                        NSEvent.ModifierFlags.shift.rawValue
            
            let actualRelevantModifiers = event.modifierFlags.rawValue & relevantModifiers
            let expectedRelevantModifiers = modifiers & relevantModifiers
            
            let modifiersMatch = actualRelevantModifiers == expectedRelevantModifiers
            
            if keyMatches && modifiersMatch {
                DispatchQueue.main.async {
                    Task { await self?.layoutManager.loadLayout(name: layoutName) }
                }
            }
        }
        
        registeredShortcuts[shortcutString] = (layoutName: layoutName, eventMonitor: eventMonitor as Any)
    }
    
    private func parseShortcutString(_ shortcutString: String) -> (keyCode: UInt16, modifiers: UInt)? {
        var modifiers: UInt = 0
        var keyString = shortcutString
        
        // Parse modifier flags
        if shortcutString.contains("⌘") {
            modifiers |= NSEvent.ModifierFlags.command.rawValue
            keyString = keyString.replacingOccurrences(of: "⌘", with: "")
        }
        if shortcutString.contains("⌥") {
            modifiers |= NSEvent.ModifierFlags.option.rawValue
            keyString = keyString.replacingOccurrences(of: "⌥", with: "")
        }
        if shortcutString.contains("⌃") {
            modifiers |= NSEvent.ModifierFlags.control.rawValue
            keyString = keyString.replacingOccurrences(of: "⌃", with: "")
        }
        if shortcutString.contains("⇧") {
            modifiers |= NSEvent.ModifierFlags.shift.rawValue
            keyString = keyString.replacingOccurrences(of: "⇧", with: "")
        }
        
        // Parse key code
        guard let keyCode = stringToKeyCode(keyString) else { return nil }
        
        return (keyCode: keyCode, modifiers: modifiers)
    }
    
    private func stringToKeyCode(_ keyString: String) -> UInt16? {
        switch keyString {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "O": return 31
        case "U": return 32
        case "[": return 33
        case "I": return 34
        case "P": return 35
        case "Return": return 36
        case "L": return 37
        case "J": return 38
        case "'": return 39
        case "K": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "N": return 45
        case "M": return 46
        case ".": return 47
        case "Tab": return 48
        case "Space": return 49
        case "`": return 50
        case "Delete": return 51
        case "Escape": return 53
        case "←": return 123
        case "→": return 124
        case "↓": return 125
        case "↑": return 126
        default: return nil
        }
    }
}

// MARK: - Key Capture View
class KeyCaptureView: NSView {
    var onKeyCaptured: ((String) -> Void)?
    private var isCapturing = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupKeyCapture()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupKeyCapture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeyCapture()
    }
    
    private func setupKeyCapture() {
        // The view will be made first responder when startCapturing() is called
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard isCapturing else { return }
        
        let modifiers = event.modifierFlags
        let keyCode = event.keyCode
        
        // Build shortcut string
        var shortcutParts: [String] = []
        
        if modifiers.contains(.command) { shortcutParts.append("⌘") }
        if modifiers.contains(.option) { shortcutParts.append("⌥") }
        if modifiers.contains(.control) { shortcutParts.append("⌃") }
        if modifiers.contains(.shift) { shortcutParts.append("⇧") }
        
        // Add the key
        if let key = keyCodeToString(keyCode) {
            shortcutParts.append(key)
        }
        
        let shortcut = shortcutParts.joined(separator: "")
        onKeyCaptured?(shortcut)
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
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
        case 36: return "Return"
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
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }
    
    func startCapturing() {
        isCapturing = true
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }
    
    func stopCapturing() {
        isCapturing = false
    }
}