//
//  TimelockApp.swift
//  Timelock
//
//  Created by Eddy Mogollon on 9/25/26.
//

import SwiftUI

@main
struct TimelockApp: App {
    var body: some Scene {
        MenuBarExtra("Timelock", systemImage: "clock") {
            Button("Quit Timelock") { NSApplication.shared.terminate(nil) }
        }
    }
}
