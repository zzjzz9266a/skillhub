import Foundation
import Combine

final class AppViewModel: ObservableObject {
    // MARK: - Published state
    @Published var sources: [Source] = []
    @Published var skills: [Skill] = []
    @Published var agents: [Agent] = []
    @Published var agentSkillStates: [Int64: [Int64: Bool]] = [:]
    @Published var selectedSourceId: Int64?
    @Published var installInput: String = ""
    @Published var statusText: String = ""

    // MARK: - Services
    let database: DatabaseService
    let skillService: SkillService
    let agentService: AgentService
    let syncService: SyncService

    init(homeOverride: String? = nil) {
        let homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = (homePath as NSString).appendingPathComponent(".skillhub/state.db")

        self.database = (try? DatabaseService(path: dbPath)) ?? (try! DatabaseService(inMemory: true))
        self.skillService = SkillService(database: database)
        self.agentService = AgentService(database: database, homeOverride: homePath)
        self.syncService = SyncService(database: database, homeOverride: homePath)
    }

    // MARK: - Lifecycle

    func refresh() {
        refreshSources()
        refreshSkills()
        let found = agentService.detect()
        self.agents = found
        refreshAllAgentStates()
        updateStatus()
    }

    private func refreshSources() {
        self.sources = (try? database.dbQueue.read { db in try Source.fetchAll(db) }) ?? []
    }

    private func refreshSkills() {
        self.skills = (try? database.dbQueue.read { db in try Skill.fetchAll(db) }) ?? []
    }

    private func refreshAllAgentStates() {
        for agent in agents {
            let states = (try? syncService.getAgentSkillStates(agentId: agent.id)) ?? [:]
            agentSkillStates[agent.id] = states
        }
    }

    private func updateStatus() {
        let agentCount = agents.count
        let skillCount = skills.count
        statusText = "\(agentCount) agents detected | \(skillCount) skills installed"
    }

    // MARK: - Toggle operations

    func toggleSkill(skillId: Int64, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        try? FileManager.default.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)

        if enabled {
            try? syncService.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
        } else {
            try? syncService.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
        }

        agentSkillStates[agentId, default: [:]][skillId] = enabled
    }

    func toggleSource(sourceId: Int64, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        let sourceSkills = skills.filter { $0.sourceId == sourceId }
        for skill in sourceSkills {
            if enabled {
                try? syncService.enableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: skillsDir)
            } else {
                try? syncService.disableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: skillsDir)
            }
        }

        for skill in sourceSkills {
            agentSkillStates[agentId, default: [:]][skill.id] = enabled
        }
    }

    func toggleGroup(sourceId: Int64, groupName: String, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        let groupSkills = skills.filter { $0.sourceId == sourceId && $0.groups.contains(groupName) }
        for skill in groupSkills {
            if enabled {
                try? syncService.enableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: skillsDir)
            } else {
                try? syncService.disableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: skillsDir)
            }
        }

        for skill in groupSkills {
            agentSkillStates[agentId, default: [:]][skill.id] = enabled
        }
    }

    // MARK: - Install

    func install() {
        guard !installInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        statusText = "Installing..."
        let input = installInput.trimmingCharacters(in: .whitespaces)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let sourceName = (input as NSString).lastPathComponent
                    .replacingOccurrences(of: ".git", with: "")
                _ = try self.skillService.install(from: input, sourceName: sourceName, sourceLabel: sourceName)
                DispatchQueue.main.async {
                    self.installInput = ""
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusText = "Install failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Helpers

    private func agentSkillsDirectory(for agent: Agent) -> String {
        if let configPath = agent.configPath {
            return (configPath as NSString).appendingPathComponent("skills")
        }
        let pathMap: [String: String] = [
            "Claude Code": ".claude",
            "OpenCode": ".opencode",
            "Gemini CLI": ".gemini",
            "Codex": ".codex",
            "Copilot CLI": ".config/github-copilot",
        ]
        let home = agentService.homePath
        let relative = pathMap[agent.name] ?? ".claude"
        return (home as NSString).appendingPathComponent("\(relative)/skills")
    }

    var filteredSkills: [Skill] {
        guard let sourceId = selectedSourceId else { return skills }
        return skills.filter { $0.sourceId == sourceId }
    }

    func skillsForSource(_ sourceId: Int64) -> [Skill] {
        return skills.filter { $0.sourceId == sourceId }
    }
}
