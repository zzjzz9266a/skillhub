import Foundation

enum SourceType: Equatable {
    case git(url: String)
    case npm(name: String)
    case local(path: String)
}

enum SourceParser {
    static func parse(_ input: String) -> SourceType? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Git: https://, git@, ssh://, or .git suffix
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("git@") || trimmed.hasPrefix("ssh://") {
            return .git(url: trimmed)
        }
        if trimmed.hasSuffix(".git") {
            return .git(url: trimmed)
        }

        // npm: @scope/name or package-name (no slashes, no dots as path)
        if trimmed.hasPrefix("@") && trimmed.contains("/") {
            return .npm(name: trimmed)
        }

        // local: must be an existing directory
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory), isDirectory.boolValue {
            return .local(path: trimmed)
        }

        return nil
    }
}
