import SwiftUI
import AppKit
import Combine

/// Manages dynamic icon behavior for Snap window manager
@MainActor
class DynamicIconManager: ObservableObject {
    static let shared = DynamicIconManager()
    
    @Published var currentIconState: IconState = .normal
    
    enum IconState {
        case normal
        case active
        case processing
        case error
    }
    
    private init() {
        setupDynamicIcon()
    }
    
    /// Set up dynamic icon with system appearance changes
    private func setupDynamicIcon() {
        // Initial icon update
        updateIconForCurrentAppearance()
    }
    
    /// Update icon based on current system appearance
    private func updateIconForCurrentAppearance() {
        // The Icon Composer design automatically adapts to light/dark mode
        // through the "appearance" : "dark" specialization in icon.json
        
        // Force icon refresh by updating the app icon
        DispatchQueue.main.async {
            if let icon = NSImage(named: "Snap") {
                NSApp.applicationIconImage = icon
            }
        }
    }
    
    /// Update icon state based on app activity
    func updateIconState(_ state: IconState) {
        currentIconState = state
        
        // The Icon Composer design supports dynamic scaling and translucency
        // which can be leveraged for different states
        
        switch state {
        case .normal:
            // Use default icon appearance
            break
        case .active:
            // Could trigger subtle animation or highlight
            break
        case .processing:
            // Could show processing state
            break
        case .error:
            // Could show error state
            break
        }
        
        // Force icon refresh
        updateIconForCurrentAppearance()
    }
    
    /// Get current icon with dynamic properties
    func getCurrentIcon() -> NSImage? {
        return NSImage(named: "Snap")
    }
}

/// Extension to provide dynamic icon functionality to the main app
extension DynamicIconManager {
    
    /// Called when window management operations start
    func startWindowOperation() {
        updateIconState(.processing)
    }
    
    /// Called when window management operations complete
    func completeWindowOperation() {
        updateIconState(.normal)
    }
    
    /// Called when an error occurs
    func showError() {
        updateIconState(.error)
        
        // Reset to normal after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateIconState(.normal)
        }
    }
}