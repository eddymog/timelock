import Foundation
import Observation

enum CommitmentPreset: Int, CaseIterable, Identifiable {
    case none = 0
    case twentyFive = 25
    case fifty = 50
    case ninety = 90

    var id: Self { self }
    var title: String { self == .none ? "None" : "\(rawValue) min" }
    var duration: TimeInterval? { self == .none ? nil : TimeInterval(rawValue * 60) }
}

enum BrowserStartBehavior: String, CaseIterable, Identifiable {
    case ask
    case close
    case keepOpen

    var id: Self { self }

    var title: String {
        switch self {
        case .ask: "Always Ask"
        case .close: "Close Automatically"
        case .keepOpen: "Keep Open"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    var defaultCommitment: CommitmentPreset {
        didSet { defaults.set(defaultCommitment.rawValue, forKey: Keys.defaultCommitment) }
    }
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var browserStartBehavior: BrowserStartBehavior {
        didSet { defaults.set(browserStartBehavior.rawValue, forKey: Keys.browserStartBehavior) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultCommitment = CommitmentPreset(
            rawValue: defaults.integer(forKey: Keys.defaultCommitment)
        ) ?? .none
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        browserStartBehavior = BrowserStartBehavior(
            rawValue: defaults.string(forKey: Keys.browserStartBehavior) ?? ""
        ) ?? .ask
    }

    private enum Keys {
        static let defaultCommitment = "defaultCommitmentMinutes"
        static let notificationsEnabled = "notificationsEnabled"
        static let browserStartBehavior = "browserStartBehavior"
    }
}
