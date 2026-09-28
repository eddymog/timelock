import AppKit
import Foundation

@MainActor
final class BrowserController {
    func runningBrowsers() -> [NSRunningApplication] {
        guard let webURL = URL(string: "https://example.com") else { return [] }
        let browserPaths = Set(
            NSWorkspace.shared.urlsForApplications(toOpen: webURL)
                .map { $0.standardizedFileURL.path }
        )

        return NSWorkspace.shared.runningApplications
            .filter { application in
                guard let bundleURL = application.bundleURL else { return false }
                return browserPaths.contains(bundleURL.standardizedFileURL.path)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    func close(_ browsers: [NSRunningApplication]) async throws {
        let runningBrowsers = browsers.filter { !$0.isTerminated }
        runningBrowsers.forEach { _ = $0.terminate() }

        if await waitUntilTerminated(runningBrowsers, timeout: 3) {
            return
        }

        runningBrowsers.filter { !$0.isTerminated }.forEach { _ = $0.forceTerminate() }
        guard await waitUntilTerminated(runningBrowsers, timeout: 2) else {
            let names = runningBrowsers
                .filter { !$0.isTerminated }
                .compactMap(\.localizedName)
                .joined(separator: ", ")
            throw BrowserControllerError.couldNotClose(names.isEmpty ? "the browser" : names)
        }
    }

    private func waitUntilTerminated(_ browsers: [NSRunningApplication], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while browsers.contains(where: { !$0.isTerminated }), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return browsers.allSatisfy(\.isTerminated)
    }
}

private enum BrowserControllerError: LocalizedError {
    case couldNotClose(String)

    var errorDescription: String? {
        switch self {
        case .couldNotClose(let names):
            "Could not close \(names). Close the browser manually, then start the activity again."
        }
    }
}
