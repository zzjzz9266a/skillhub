import Foundation
import Testing
@testable import SkillHub

struct AppViewModelTests {
    @Test func toggleSkillDoesNotUpdateStateWhenSyncFails() throws {
        let tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewmodel-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(
            atPath: (tempHome as NSString).appendingPathComponent(".skillhub"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tempHome) }

        let viewModel = AppViewModel(homeOverride: tempHome)

        var source = Source(name: "test-source", label: "Test", origin: "local", installedAt: Date())
        try viewModel.database.dbQueue.write { db in try source.insert(db) }

        let skillStorePath = (tempHome as NSString).appendingPathComponent(".skillhub/skills/test-source/my-skill")
        try FileManager.default.createDirectory(atPath: skillStorePath, withIntermediateDirectories: true)
        var skill = Skill(
            name: "my-skill",
            sourceId: source.id,
            installPath: skillStorePath,
            groups: [],
            version: nil,
            installedAt: Date(),
            updatedAt: Date()
        )
        try viewModel.database.dbQueue.write { db in try skill.insert(db) }

        var agent = Agent(
            name: "Claude Code",
            configPath: (tempHome as NSString).appendingPathComponent(".claude"),
            detectedAt: Date(),
            visible: true,
            installed: true
        )
        try viewModel.database.dbQueue.write { db in try agent.insert(db) }

        let unmanagedPath = (tempHome as NSString).appendingPathComponent(".claude/skills/my-skill")
        try FileManager.default.createDirectory(atPath: unmanagedPath, withIntermediateDirectories: true)

        viewModel.agents = [agent]
        viewModel.skills = [skill]
        viewModel.toggleSkill(skillId: skill.id, agentId: agent.id, enabled: true)

        #expect(viewModel.agentSkillStates[agent.id]?[skill.id] != true)
        #expect(viewModel.statusText.contains("non-SkillHub"))
        let attrs = try FileManager.default.attributesOfItem(atPath: unmanagedPath)
        #expect(attrs[.type] as? FileAttributeType == .typeDirectory)
    }
}
