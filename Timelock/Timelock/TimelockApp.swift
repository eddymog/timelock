//
//  TimelockApp.swift
//  Timelock
//
//  Created by Eddy Mogollon on 9/25/26.
//

import SwiftUI
import SwiftData

enum WindowID {
    static let main = "main"
    static let activities = "activities"
}

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

        try? ActivitySeeder.seedIfEmpty(container.mainContext)
        let timer = TimerService(context: container.mainContext)
        timer.recoverOnLaunch()
        _timer = State(initialValue: timer)
    }

    var body: some Scene {
        Window("Timelock", id: WindowID.main) {
            MainView(timer: timer)
        }
        .windowResizability(.contentSize)
        .modelContainer(container)

        Window("Activities", id: WindowID.activities) {
            ActivityEditorView()
        }
        .modelContainer(container)
    }
}
