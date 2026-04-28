import GRDB
import Foundation

struct AgentDefinition {
    let name: String
    let configPaths: [String]
    let hotReloadSupported: Bool
}

final class AgentService {
    let database: DatabaseService
    let homePath: String

    static let knownAgents: [AgentDefinition] = [
        AgentDefinition(name: "Claude Code", configPaths: [".claude"], hotReloadSupported: false),
        AgentDefinition(name: "OpenCode", configPaths: [".opencode"], hotReloadSupported: false),
        AgentDefinition(name: "Gemini CLI", configPaths: [".gemini"], hotReloadSupported: false),
        AgentDefinition(name: "Codex", configPaths: [".codex"], hotReloadSupported: false),
        AgentDefinition(name: "Copilot CLI", configPaths: [".config/github-copilot"], hotReloadSupported: false),
    ]

    init(database: DatabaseService, homeOverride: String? = nil) {
        self.database = database
        self.homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    @discardableResult
    func detect() -> [Agent] {
        let found = Self.knownAgents.compactMap { def -> Agent? in
            let exists = def.configPaths.contains { configPath in
                let fullPath = (homePath as NSString).appendingPathComponent(configPath)
                return FileManager.default.fileExists(atPath: fullPath)
            }
            guard exists else { return nil }
            return Agent(
                name: def.name,
                configPath: def.configPaths.first.map { (homePath as NSString).appendingPathComponent($0) },
                detectedAt: Date(),
                hotReloadSupported: def.hotReloadSupported
            )
        }

        try? database.dbQueue.write { db in
            try Agent.deleteAll(db)
            for var agent in found {
                try agent.insert(db)
            }
        }

        return found
    }

    func listAgents() throws -> [Agent] {
        return try database.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
    }
}
