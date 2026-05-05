import GRDB
import Foundation

struct AgentDefinition {
    let name: String
    let configPaths: [String]
    let skillsSubdirectory: String
    let visibleByDefault: Bool
}

final class AgentService {
    let database: DatabaseService
    let homePath: String

    static let knownAgents: [AgentDefinition] = [
        AgentDefinition(name: "Claude Code", configPaths: [".claude"], skillsSubdirectory: "skills", visibleByDefault: true),
        AgentDefinition(name: "Codex", configPaths: [".codex"], skillsSubdirectory: "skills", visibleByDefault: true),
        AgentDefinition(name: "OpenCode", configPaths: [".config/opencode"], skillsSubdirectory: "skills", visibleByDefault: true),
        AgentDefinition(name: "Gemini CLI", configPaths: [".gemini"], skillsSubdirectory: "skills", visibleByDefault: false),
        AgentDefinition(name: "Copilot CLI", configPaths: [".config/github-copilot"], skillsSubdirectory: "skills", visibleByDefault: false),
        AgentDefinition(name: "OpenClaw", configPaths: [".openclaw"], skillsSubdirectory: "skills", visibleByDefault: false),
        AgentDefinition(name: "Hermes", configPaths: [".hermes"], skillsSubdirectory: "skills", visibleByDefault: false),
    ]

    init(database: DatabaseService, homeOverride: String? = nil) {
        self.database = database
        self.homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    @discardableResult
    func detect() -> [Agent] {
        let agentsToUpsert = Self.knownAgents.map { def -> Agent in
            let exists = def.configPaths.contains { configPath in
                let fullPath = (homePath as NSString).appendingPathComponent(configPath)
                return FileManager.default.fileExists(atPath: fullPath)
            }
            return Agent(
                name: def.name,
                configPath: def.configPaths.first.map { (homePath as NSString).appendingPathComponent($0) },
                detectedAt: Date(),
                visible: def.visibleByDefault,
                installed: exists
            )
        }

        try? database.dbQueue.write { db in
            let existing = (try? Agent.fetchAll(db)) ?? []
            var existingByName: [String: Agent] = [:]
            for agent in existing {
                existingByName[agent.name] = agent
            }

            for var agent in agentsToUpsert {
                if let match = existingByName[agent.name] {
                    agent.id = match.id
                    agent.visible = match.visible
                }
                try agent.save(db)
            }

            let knownNames = Set(Self.knownAgents.map(\.name))
            let staleNames = Set(existingByName.keys).subtracting(knownNames)
            for name in staleNames {
                if let agent = existingByName[name] {
                    try Agent.deleteOne(db, key: agent.id)
                }
            }
        }

        return (try? database.dbQueue.read { db in
            try Agent.fetchAll(db)
        }) ?? []
    }

    func listAgents() throws -> [Agent] {
        return try database.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
    }
}
