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
    @State private var errors: ErrorCenter

    init() {
        let schema = Schema([
            Activity.self,
            BlockGroup.self,
            BlockRule.self,
            Session.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.container = container

        let errors = ErrorCenter()
        errors.perform("Creating the starter activity") { try ActivitySeeder.seedIfEmpty(container.mainContext) }
        let timer = TimerService(context: container.mainContext, errors: errors)
        timer.recoverOnLaunch()
        _timer = State(initialValue: timer)
        _errors = State(initialValue: errors)
    }

    var body: some Scene {
        Window("Timelock", id: WindowID.main) {
            MainView(timer: timer)
        }
        .windowResizability(.contentSize)
        .modelContainer(container)
        .environment(errors)

        Window("Activities", id: WindowID.activities) {
            ActivityEditorView()
        }
        .modelContainer(container)
        .environment(errors)
    }
}
