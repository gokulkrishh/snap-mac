//
//  snapApp.swift
//  snap
//
//  Created by Gokulakrishnan Kalaikovan on 24/09/25.
//

import SwiftUI

@main
struct SnapApp: App {
    @StateObject private var manager = LayoutManager()

    var body: some Scene {
        MenuBarExtra("Snap", systemImage: "macwindow") {
            MenuBarContent(manager: manager)
        }
    }
}