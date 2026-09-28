import Foundation
import Observation

@MainActor
protocol AppBlocking {
    func start(bundleIDs: [String], activityName: String)
    func stop()
}

@MainActor
@Observable
final class BlockingCoordinator {
    private(set) var websiteWarning: String?

    private let appBlocker: AppBlocking
    @ObservationIgnored private let websiteBlocker: WebsiteBlocking
    @ObservationIgnored private var websiteTask: Task<Void, Never>?

    init(appBlocker: AppBlocking) {
        self.appBlocker = appBlocker
        self.websiteBlocker = NoopWebsiteBlocker()
    }

    init(appBlocker: AppBlocking, websiteBlocker: WebsiteBlocking) {
        self.appBlocker = appBlocker
        self.websiteBlocker = websiteBlocker
    }

    func apply(activity: Activity, globalGroups: [BlockGroup]) {
        let rules = effectiveRules(for: activity, globalGroups: globalGroups)
        let appBundleIDs = rules
            .filter { $0.kind == .app }
            .map(\.value)
        let domains = DomainNormalizer.expanded(
            rules.filter { $0.kind == .website }.map(\.value)
        )

        appBlocker.start(bundleIDs: appBundleIDs, activityName: activity.name)
        enqueueWebsiteOperation { [weak self] in
            guard let self else { return }
            do {
                if domains.isEmpty {
                    try await websiteBlocker.unblock()
                } else {
                    try await websiteBlocker.block(domains)
                }
                websiteWarning = nil
            } catch {
                websiteWarning = Self.unavailableMessage
            }
        }
    }

    func clear() {
        appBlocker.stop()
        enqueueWebsiteOperation { [weak self] in
            guard let self else { return }
            do {
                try await websiteBlocker.unblock()
                websiteWarning = nil
            } catch {
                websiteWarning = Self.unavailableMessage
            }
        }
    }

    func prepareForIdleLaunch() {
        appBlocker.stop()
        enqueueWebsiteOperation { [weak self] in
            guard let self else { return }
            do {
                _ = try await websiteBlocker.status()
                try await websiteBlocker.unblock()
                websiteWarning = nil
            } catch {
                websiteWarning = Self.unavailableMessage
            }
        }
    }

    func waitForPendingWebsiteOperations() async {
        await websiteTask?.value
    }

    private func enqueueWebsiteOperation(_ operation: @escaping @MainActor () async -> Void) {
        let previousTask = websiteTask
        websiteTask = Task { @MainActor in
            await previousTask?.value
            await operation()
        }
    }

    private static let unavailableMessage = "Website blocking unavailable – run install.sh"
}

func effectiveRules(for activity: Activity, globalGroups: [BlockGroup]) -> [BlockRule] {
    var seen = Set<RuleKey>()
    var result: [BlockRule] = []

    for rule in activity.rules + activity.groups.flatMap(\.rules) + globalGroups.flatMap(\.rules) {
        let key = RuleKey(kind: rule.kind, value: rule.value)
        guard seen.insert(key).inserted else { continue }
        result.append(rule)
    }

    return result
}

private struct RuleKey: Hashable {
    let kind: BlockRuleKind
    let value: String
}
