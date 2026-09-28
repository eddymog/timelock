import Foundation

struct HostsFileBlocker: WebsiteBlocking {
    private let sudoURL: URL
    private let scriptPath: String

    init(
        sudoURL: URL = URL(fileURLWithPath: "/usr/bin/sudo"),
        scriptPath: String = "/usr/local/bin/timelock-hosts"
    ) {
        self.sudoURL = sudoURL
        self.scriptPath = scriptPath
    }

    func block(_ domains: [String]) async throws {
        guard !domains.isEmpty else {
            try await unblock()
            return
        }
        _ = try await run(["-n", scriptPath, "block"] + domains)
    }

    func unblock() async throws {
        _ = try await run(["-n", scriptPath, "unblock"])
    }

    func status() async throws -> WebsiteBlockerStatus {
        let output = try await run(["-n", scriptPath, "status"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch output {
        case "active": return .active
        case "inactive": return .inactive
        default: throw HostsFileBlockerError.invalidStatus(output)
        }
    }

    private func run(_ arguments: [String]) async throws -> String {
        let executableURL = sudoURL
        return try await Task.detached {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            do {
                try process.run()
            } catch {
                throw HostsFileBlockerError.couldNotRun(error.localizedDescription)
            }
            process.waitUntilExit()

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: outputData, as: UTF8.self)
            let errorOutput = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard process.terminationStatus == 0 else {
                throw HostsFileBlockerError.commandFailed(
                    status: process.terminationStatus,
                    message: errorOutput.isEmpty ? "No error details were provided." : errorOutput
                )
            }
            return output
        }.value
    }
}

enum HostsFileBlockerError: LocalizedError, Equatable {
    case couldNotRun(String)
    case commandFailed(status: Int32, message: String)
    case invalidStatus(String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let message):
            "Could not run timelock-hosts: \(message)"
        case .commandFailed(let status, let message):
            "timelock-hosts exited with status \(status): \(message)"
        case .invalidStatus(let output):
            "timelock-hosts returned an unknown status: \(output)"
        }
    }
}
