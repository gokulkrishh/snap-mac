//
//  snapApp.swift
//  snap
//
//  Created by Gokulakrishnan Kalaikovan on 24/09/25.
//

import SwiftUI
import AppKit

@main
struct SnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuManager: AppKitMenuManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the menu manager
        menuManager = AppKitMenuManager()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running even when no windows are open
    }
}