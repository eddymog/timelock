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
    private let container: ModelContainer
    @State private var timer: TimerService

    init() {
        let schema = Schema([
            Activity.self,
            BlockGroup.self,
            BlockRule.self,
            Session.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let timer = TimerService(context: container.mainContext)
        timer.recoverOnLaunch()
        _timer = State(initialValue: timer)
    }

    var body: some Scene {
        MenuBarExtra("Timelock", systemImage: "clock") {
            Button("Quit Timelock") { NSApplication.shared.terminate(nil) }
        }
        .modelContainer(container)
    }
}
