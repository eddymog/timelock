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
    @State private var blockingCoordinator: BlockingCoordinator

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
        let blocker = AppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: blocker, websiteBlocker: HostsFileBlocker())
        let timer = TimerService(context: container.mainContext, errors: errors, blockingCoordinator: coordinator)
        timer.recoverOnLaunch()
        _timer = State(initialValue: timer)
        _errors = State(initialValue: errors)
        _blockingCoordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        Window("Timelock", id: WindowID.main) {
            MainView(timer: timer, blockingCoordinator: blockingCoordinator)
        }
        .defaultSize(width: 820, height: 560)
        .modelContainer(container)
        .environment(errors)

        Window("Activities", id: WindowID.activities) {
            ActivityEditorView()
        }
        .modelContainer(container)
        .environment(errors)
    }
}
