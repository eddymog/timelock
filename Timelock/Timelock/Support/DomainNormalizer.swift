import Foundation

enum DomainNormalizer {
    private static let domainPattern = #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"#

    static func normalize(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \Character.isWhitespace) else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.user == nil,
              components.password == nil,
              var host = components.host?.lowercased()
        else {
            return nil
        }

        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        guard host.range(of: domainPattern, options: .regularExpression) == host.startIndex..<host.endIndex else {
            return nil
        }
        return host
    }

    static func expanded(_ domains: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for domain in domains {
            let candidates = domain.hasPrefix("www.") ? [domain] : [domain, "www.\(domain)"]
            for candidate in candidates where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }
        return result
    }
}
