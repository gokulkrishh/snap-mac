import SwiftUI
import CoreGraphics
import ApplicationServices
import Combine
import AppKit

@MainActor
class LayoutManager: ObservableObject {
    static let shared = LayoutManager()
    
    @Published var layouts: [String: NSDictionary] = [:]
    private let dynamicIconManager = DynamicIconManager.shared

    private init() {
        loadLayouts()
        // Global shortcuts are now handled by AppKitMenuManager to avoid conflicts
    }

    private func loadLayouts() {
        self.layouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
    }
    
    func saveLayout() async {
        await saveLayoutWithName(nil)
    }
    
    func replaceLayout(name: String) async {
        await saveLayoutWithName(name)
    }
    
    private func saveLayoutWithName(_ layoutName: String?) async {
        dynamicIconManager.startWindowOperation()
        
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
            // Preserve existing shortcut status
            if let existingLayout = savedLayouts[layoutName] as? [String: Any] {
                let data = try! JSONSerialization.data(withJSONObject: layoutData)
                let dataString = data.base64EncodedString()
                let shortcutValue = existingLayout["shortcut"] as? String ?? ""
                let layoutDict: [String: Any] = [
                    "data": dataString,
                    "date": Date(),
                    "shortcut": shortcutValue,
                ]
                savedLayouts[name] = layoutDict as NSDictionary
            } else {
                let data = try! JSONSerialization.data(withJSONObject: layoutData)
                let dataString = data.base64EncodedString()
                let layoutDict: [String: Any] = ["data": dataString, "date": Date()]
                savedLayouts[name] = layoutDict as NSDictionary
            }
        } else {
            // Create new layout
            name = "Layout \(savedLayouts.count + 1)"
            let data = try! JSONSerialization.data(withJSONObject: layoutData)
            let dataString = data.base64EncodedString()
            let layoutDict: [String: Any] = ["data": dataString, "date": Date()]
            savedLayouts[name] = layoutDict as NSDictionary
        }
        
        UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        UserDefaults.standard.synchronize()
        DispatchQueue.main.async {
            self.layouts = savedLayouts
            self.dynamicIconManager.completeWindowOperation()
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
              let layoutDict = layouts[name] else {
            return
        }
        
        var data: Data
        if let dataString = layoutDict["data"] as? String {
            // New format: base64 encoded string
            guard let decodedData = Data(base64Encoded: dataString) else { return }
            data = decodedData
        } else if let nsData = layoutDict["data"] as? Data {
            // Old format: NSData
            data = nsData
        } else {
            return
        }
        
        guard let savedLayouts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
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
        for (index, saved) in filteredLayouts.enumerated() {
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
            var windowFound = false

            // Find the window with matching name first
            var targetWindowElement: AXUIElement?
            var targetWindowTitle = ""
            
            for i in 0..<CFArrayGetCount(windows) {
                let window = CFArrayGetValueAtIndex(windows, i)
                let windowElement = unsafeBitCast(window, to: AXUIElement.self)

                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &title)
                let windowTitle = title as? String ?? ""

                if windowTitle == savedName || (savedName.isEmpty && windowTitle.isEmpty) {
                    targetWindowElement = windowElement
                    targetWindowTitle = windowTitle
                    break
                }
            }
            
            // If no exact match found, use the first available window from this app
            // This is more aggressive and ensures the app gets repositioned even if window titles changed
            if targetWindowElement == nil && CFArrayGetCount(windows) > 0 {
                let window = CFArrayGetValueAtIndex(windows, 0)
                targetWindowElement = unsafeBitCast(window, to: AXUIElement.self)
                
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(targetWindowElement!, kAXTitleAttribute as CFString, &title)
                targetWindowTitle = title as? String ?? ""
            }
            
            // Apply the layout to the target window
            if let windowElement = targetWindowElement {
                // Get current window position and size to check if it needs to be moved
                var currentPosition: CFTypeRef?
                var currentSize: CFTypeRef?
                AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &currentPosition)
                AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &currentSize)
                
                var currentPos = CGPoint.zero
                var currentSz = CGSize.zero
                
                if let pos = currentPosition {
                    AXValueGetValue(pos as! AXValue, .cgPoint, &currentPos)
                }
                if let sz = currentSize {
                    AXValueGetValue(sz as! AXValue, .cgSize, &currentSz)
                }
                
                let targetPosition = CGPoint(x: x, y: y)
                let targetSize = CGSize(width: width, height: height)
                
                // Always move the window to ensure it's in the correct position
                // This fixes the issue where switching between layouts with the same app doesn't work
                // Use a small tolerance to avoid unnecessary moves for tiny differences
                let positionTolerance: CGFloat = 2.0
                let sizeTolerance: CGFloat = 2.0
                
                let positionMatches = abs(currentPos.x - targetPosition.x) < positionTolerance && 
                                    abs(currentPos.y - targetPosition.y) < positionTolerance
                let sizeMatches = abs(currentSz.width - targetSize.width) < sizeTolerance && 
                                abs(currentSz.height - targetSize.height) < sizeTolerance
                
                // Always apply the layout, even if position/size are close
                // This ensures consistent behavior when switching between layouts
                if !positionMatches || !sizeMatches {
                    // Set position
                    var position = targetPosition
                    let posValue = AXValueCreate(.cgPoint, &position)
                    let posResult = AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posValue!)
                    if posResult != AXError.success {
                        continue
                    }

                    // Set size
                    var size = targetSize
                    let sizeValue = AXValueCreate(.cgSize, &size)
                    let sizeResult = AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue!)
                    if sizeResult != AXError.success {
                        continue
                    }
                }
                
                windowFound = true
            }
            
            // Add a small delay between window operations to ensure system stability
            // This helps prevent race conditions when multiple windows are being repositioned
            if index < filteredLayouts.count - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
        }
    }

    func deleteLayout(name: String) {
        var savedLayouts = UserDefaults.standard.dictionary(forKey: "layouts") as? [String: NSDictionary] ?? [:]
        savedLayouts.removeValue(forKey: name)
        UserDefaults.standard.set(savedLayouts, forKey: "layouts")
        UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
            
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
            UserDefaults.standard.synchronize()
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.layouts = savedLayouts
            }
        }
    }
}