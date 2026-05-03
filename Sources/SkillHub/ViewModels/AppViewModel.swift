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
    @Published var isResolving: Bool = false
    @Published var showPreview: Bool = false
    @Published var previewSkills: [SkillService.DiscoveredSkill] = []
    @Published var previewIsReinstall: Bool = false
    var previewResolvedSource: SkillService.ResolvedSource?
    var previewSourceName: String = ""
    var previewSourceLabel: String = ""

    // MARK: - Services
    let database: DatabaseService
    let skillService: SkillService
    let agentService: AgentService
    let syncService: SyncService
    let configService: ConfigService

    var lastLocalWrite: Date = .distantPast

    init(homeOverride: String? = nil) {
        let homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = (homePath as NSString).appendingPathComponent(".skillhub/state.db")

        self.database = (try? DatabaseService(path: dbPath)) ?? (try! DatabaseService(inMemory: true))
        self.skillService = SkillService(database: database)
        self.agentService = AgentService(database: database, homeOverride: homePath)
        self.syncService = SyncService(database: database, homeOverride: homePath)
        self.configService = ConfigService(homeOverride: homePath)
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

        lastLocalWrite = Date()
        do {
            if enabled {
                try syncService.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
            } else {
                try syncService.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
            }
            agentSkillStates[agentId] = try syncService.getAgentSkillStates(agentId: agentId)
            statusText = enabled ? "Skill enabled" : "Skill disabled"
        } catch {
            agentSkillStates[agentId] = (try? syncService.getAgentSkillStates(agentId: agentId)) ?? agentSkillStates[agentId] ?? [:]
            statusText = "Sync failed: \(error.localizedDescription)"
        }
    }

    func toggleSource(sourceId: Int64, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        let sourceSkills = skills.filter { $0.sourceId == sourceId }
        lastLocalWrite = Date()
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

        let groupSkills = skills.filter { $0.sourceId == sourceId && skill($0, belongsTo: groupName) }
        lastLocalWrite = Date()
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

    // MARK: - Delete

    func deleteSource(_ sourceId: Int64) {
        // Get source name for YAML cleanup
        let sourceName = sources.first { $0.id == sourceId }?.name

        // Clean up symlinks for all agents
        for agent in agents {
            let skillsDir = agentSkillsDirectory(for: agent)
            let sourceSkills = skillsForSource(sourceId)
            for skill in sourceSkills {
                let linkPath = (skillsDir as NSString).appendingPathComponent(skill.name)
                try? FileManager.default.removeItem(atPath: linkPath)
            }
        }

        try? skillService.deleteSource(sourceId)
        if let name = sourceName {
            try? configService.removeSource(name: name)
        }
        refresh()
    }

    // MARK: - Install

    func install() {
        guard !installInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isResolving = true
        statusText = "Resolving..."
        let input = installInput.trimmingCharacters(in: .whitespaces)

        let sourceName = (input as NSString).lastPathComponent
            .replacingOccurrences(of: ".git", with: "")

        let isReinstall = sources.contains { $0.name == sourceName || $0.origin == input }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let resolved = try self.skillService.preview(from: input)
                DispatchQueue.main.async {
                    self.isResolving = false
                    self.previewSourceName = sourceName
                    self.previewSourceLabel = sourceName
                    self.previewSkills = resolved.skills
                    self.previewResolvedSource = resolved
                    self.previewIsReinstall = isReinstall || self.sources.contains { $0.name == sourceName || $0.origin == resolved.originalInput }
                    self.showPreview = true
                    self.statusText = resolved.skills.isEmpty
                        ? "No SKILL.md files found in \"\(sourceName)\""
                        : "\(resolved.skills.count) skill\(resolved.skills.count == 1 ? "" : "s") found"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isResolving = false
                    self.statusText = "Resolve failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func confirmInstall() {
        guard let resolved = previewResolvedSource else { return }
        statusText = "Installing..."
        showPreview = false

        let sourceName = previewSourceName
        let sourceLabel = previewSourceLabel
        let selectedSkills = previewSkills

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                _ = try self.skillService.confirmInstall(
                    resolved: resolved,
                    sourceName: sourceName,
                    sourceLabel: sourceLabel,
                    selectedSkills: selectedSkills
                )
                // Persist to sources.yaml
                let groups = Dictionary(grouping: selectedSkills) { $0.groups.first ?? "ungrouped" }
                    .mapValues { $0.map { $0.name } }
                try? self.configService.addSource(name: sourceName, label: sourceLabel, origin: resolved.originalInput)
                if !groups.isEmpty {
                    try? self.configService.setGroups(name: sourceName, groups: groups)
                }
                // Clean up temp clone directory
                if let dir = resolved.tempDir {
                    try? FileManager.default.removeItem(atPath: dir)
                }
                DispatchQueue.main.async {
                    self.installInput = ""
                    self.previewResolvedSource = nil
                    self.previewSkills = []
                    self.refresh()
                }
            } catch {
                if let dir = resolved.tempDir {
                    try? FileManager.default.removeItem(atPath: dir)
                }
                DispatchQueue.main.async {
                    self.statusText = "Install failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func cancelPreview() {
        if let dir = previewResolvedSource?.tempDir {
            try? FileManager.default.removeItem(atPath: dir)
        }
        isResolving = false
        showPreview = false
        previewSkills = []
        previewResolvedSource = nil
        previewIsReinstall = false
        statusText = ""
    }

    // MARK: - Tree structure for matrix

    @Published var expandedSources: Set<Int64> = []
    @Published var expandedGroups: Set<String> = []

    func isSourceExpanded(sourceId: Int64) -> Bool {
        expandedSources.contains(sourceId)
    }

    func toggleSourceExpanded(sourceId: Int64) {
        if expandedSources.contains(sourceId) {
            expandedSources.remove(sourceId)
        } else {
            expandedSources.insert(sourceId)
        }
    }

    func groupKey(sourceId: Int64, groupName: String) -> String {
        "\(sourceId)/\(groupName)"
    }

    func isGroupExpanded(sourceId: Int64, groupName: String) -> Bool {
        expandedGroups.contains(groupKey(sourceId: sourceId, groupName: groupName))
    }

    func toggleGroupExpanded(sourceId: Int64, groupName: String) {
        let key = groupKey(sourceId: sourceId, groupName: groupName)
        if expandedGroups.contains(key) {
            expandedGroups.remove(key)
        } else {
            expandedGroups.insert(key)
        }
    }

    /// Source → Group → Skill tree for the matrix
    func buildTree() -> [(source: Source, groups: [(name: String, skills: [Skill])])] {
        let sourceList = selectedSourceId == nil
            ? sources
            : sources.filter { $0.id == selectedSourceId }

        return sourceList.map { source in
            let sourceSkills = skillsForSource(source.id)
            let grouped = Dictionary(grouping: sourceSkills) { skill in
                skill.groups.first ?? "ungrouped"
            }
            let sortedGroups = grouped
                .map { (name: $0.key, skills: $0.value) }
                .sorted { a, b in
                    if a.name == "ungrouped" { return false }
                    if b.name == "ungrouped" { return true }
                    return a.name < b.name
                }
            return (source: source, groups: sortedGroups)
        }
    }

    /// Returns the batch toggle state for a group: true = all enabled, false = all disabled, nil = mixed
    func groupToggleState(sourceId: Int64, groupName: String, agentId: Int64) -> Bool? {
        let groupSkills = skills.filter { $0.sourceId == sourceId && skill($0, belongsTo: groupName) }
        guard !groupSkills.isEmpty else { return nil }
        let states = groupSkills.compactMap { agentSkillStates[agentId]?[$0.id] }
        guard states.count == groupSkills.count else { return false }
        let allEnabled = states.allSatisfy { $0 }
        let allDisabled = states.allSatisfy { !$0 }
        return allEnabled ? true : (allDisabled ? false : nil)
    }

    /// Returns the batch toggle state for a source
    func sourceToggleState(sourceId: Int64, agentId: Int64) -> Bool? {
        let sourceSkills = skillsForSource(sourceId)
        guard !sourceSkills.isEmpty else { return nil }
        let states = sourceSkills.compactMap { agentSkillStates[agentId]?[$0.id] }
        guard states.count == sourceSkills.count else { return false }
        let allEnabled = states.allSatisfy { $0 }
        let allDisabled = states.allSatisfy { !$0 }
        return allEnabled ? true : (allDisabled ? false : nil)
    }

    // MARK: - Helpers

    private func agentSkillsDirectory(for agent: Agent) -> String {
        if let configPath = agent.configPath {
            return (configPath as NSString).appendingPathComponent("skills")
        }
        let def = AgentService.knownAgents.first { $0.name == agent.name }
        let relative = def?.configPaths.first ?? ".claude"
        let home = agentService.homePath
        let configDir = (home as NSString).appendingPathComponent(relative)
        return (configDir as NSString).appendingPathComponent("skills")
    }

    var filteredSkills: [Skill] {
        guard let sourceId = selectedSourceId else { return skills }
        return skills.filter { $0.sourceId == sourceId }
    }

    var visibleAgents: [Agent] {
        agents.filter { $0.visible }
    }

    func toggleAgentVisibility(_ agentId: Int64) {
        guard let index = agents.firstIndex(where: { $0.id == agentId }) else { return }
        agents[index].visible.toggle()
        let agent = agents[index]
        try? database.dbQueue.write { db in
            try agent.update(db)
        }
    }

    func skillsForSource(_ sourceId: Int64) -> [Skill] {
        return skills.filter { $0.sourceId == sourceId }
    }

    private func skill(_ skill: Skill, belongsTo groupName: String) -> Bool {
        if skill.groups.isEmpty {
            return groupName == "ungrouped"
        }
        return skill.groups.contains(groupName)
    }
}
