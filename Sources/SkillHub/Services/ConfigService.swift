import Yams
import Foundation

struct SourceConfig: Codable {
    var label: String
    var origin: String
    var groups: [String: [String]]
}

struct SourcesConfig: Codable {
    var sources: [String: SourceConfig]
}

final class ConfigService {
    let configPath: String

    init(homeOverride: String? = nil) {
        let home = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
        let hubDir = (home as NSString).appendingPathComponent(".skillhub")
        try? FileManager.default.createDirectory(atPath: hubDir, withIntermediateDirectories: true)
        self.configPath = (hubDir as NSString).appendingPathComponent("sources.yaml")
    }

    func load() -> SourcesConfig {
        guard let data = try? String(contentsOfFile: configPath, encoding: .utf8),
              let config = try? YAMLDecoder().decode(SourcesConfig.self, from: data) else {
            return SourcesConfig(sources: [:])
        }
        return config
    }

    func save(_ config: SourcesConfig) throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(config)
        try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    func addSource(name: String, label: String, origin: String) throws {
        var config = load()
        config.sources[name] = SourceConfig(label: label, origin: origin, groups: [:])
        try save(config)
    }

    func removeSource(name: String) throws {
        var config = load()
        config.sources.removeValue(forKey: name)
        try save(config)
    }

    func setGroups(name: String, groups: [String: [String]]) throws {
        var config = load()
        config.sources[name]?.groups = groups
        try save(config)
    }
}
