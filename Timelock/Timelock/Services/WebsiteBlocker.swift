import Foundation

enum WebsiteBlockerStatus: Equatable {
    case active
    case inactive
}

@MainActor
protocol WebsiteBlocking {
    func block(_ domains: [String]) async throws
    func unblock() async throws
    func status() async throws -> WebsiteBlockerStatus
}

struct NoopWebsiteBlocker: WebsiteBlocking {
    func block(_ domains: [String]) async throws {}
    func unblock() async throws {}
    func status() async throws -> WebsiteBlockerStatus { .inactive }
}
