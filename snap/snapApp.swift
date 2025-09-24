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
        MenuBarExtra("Snap", systemImage: "window") {
            Button("Save Layout") {
                // TODO: implement save layout
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
}
