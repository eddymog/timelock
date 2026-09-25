//
//  TimelockApp.swift
//  Timelock
//
//  Created by Eddy Mogollon on 9/25/26.
//

import SwiftUI
import SwiftData

@main
struct TimelockApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            BlockGroup.self,
            BlockRule.self,
            Session.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra("Timelock", systemImage: "clock") {
            Button("Quit Timelock") { NSApplication.shared.terminate(nil) }
        }
        .modelContainer(sharedModelContainer)
    }
}
