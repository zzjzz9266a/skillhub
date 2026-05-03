import Foundation
import Testing
import GRDB
@testable import SkillHub

struct SyncServiceTests {
    let db: DatabaseService
    let sync: SyncService
    let tempHome: String
    let skillsRoot: String

    init() throws {
        db = try DatabaseService(inMemory: true)
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("synctest-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempHome, withIntermediateDirectories: true)
        skillsRoot = (tempHome as NSString).appendingPathComponent(".skillhub/skills")
        try FileManager.default.createDirectory(atPath: skillsRoot, withIntermediateDirectories: true)
        sync = SyncService(database: db, homeOverride: tempHome)
    }

    private func createFixture() throws -> (sourceId: Int64, skillId: Int64, agentId: Int64, agentSkillDir: String) {
        var source = Source(id: 0, name: "test-src", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in try source.insert(db) }
        source = try db.dbQueue.read { db in try Source.fetchOne(db)! }

        let skillPath = (skillsRoot as NSString).appendingPathComponent("test-src/my-skill")
        try FileManager.default.createDirectory(atPath: skillPath, withIntermediateDirectories: true)
        try "test content".write(toFile: (skillPath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        var skill = Skill(id: 0, name: "my-skill", sourceId: source.id, installPath: skillPath, groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill.insert(db) }
        skill = try db.dbQueue.read { db in try Skill.fetchOne(db)! }

        var agent = Agent(id: 0, name: "TestAgent", configPath: nil, detectedAt: Date(), hotReloadSupported: true, visible: true, installed: true)
        try db.dbQueue.write { db in try agent.insert(db) }
        agent = try db.dbQueue.read { db in try Agent.fetchOne(db)! }

        let agentSkillDir = (tempHome as NSString).appendingPathComponent(".claude/skills")
        try FileManager.default.createDirectory(atPath: agentSkillDir, withIntermediateDirectories: true)

        return (source.id, skill.id, agent.id, agentSkillDir)
    }

    @Test func enableSkillCreatesSymlink() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()
        try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        #expect(state != nil)
        #expect(state!.enabled)

        let linkPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        #expect(FileManager.default.fileExists(atPath: linkPath))
        let attrs = try FileManager.default.attributesOfItem(atPath: linkPath)
        #expect(attrs[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test func disableSkillRemovesSymlink() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()
        try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)
        try sync.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        if let state = state { #expect(!state.enabled) }

        let linkPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        #expect(!FileManager.default.fileExists(atPath: linkPath))
    }

    @Test func disableSkillRemovesManagedSymlinkEvenWhenTargetIsMissing() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()
        try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let skill = try db.dbQueue.read { db in try Skill.fetchOne(db)! }
        try FileManager.default.removeItem(atPath: skill.installPath)
        try sync.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let linkPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        #expect(!FileManager.default.fileExists(atPath: linkPath))
        #expect(!FileManager.default.fileExists(atPath: linkPath, isDirectory: nil))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: linkPath)) == nil)
    }

    @Test func enableSkillDoesNotReplaceUnmanagedDirectory() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()
        let unmanagedPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        try FileManager.default.createDirectory(atPath: unmanagedPath, withIntermediateDirectories: true)

        #expect(throws: (any Error).self) {
            try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: unmanagedPath)
        #expect(attrs[.type] as? FileAttributeType == .typeDirectory)
        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        #expect(state == nil)
    }

    @Test func batchEnableSource() throws {
        let (sourceId, _, agentId, agentSkillDir) = try createFixture()
        let skill2Path = (skillsRoot as NSString).appendingPathComponent("test-src/skill-2")
        try FileManager.default.createDirectory(atPath: skill2Path, withIntermediateDirectories: true)
        try "content".write(toFile: (skill2Path as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        var skill2 = Skill(id: 0, name: "skill-2", sourceId: sourceId, installPath: skill2Path, groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill2.insert(db) }

        try sync.enableSource(sourceId: sourceId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let states = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId).fetchAll(db)
        }
        #expect(states.count == 2)
        #expect(states.allSatisfy { $0.enabled })
        #expect(FileManager.default.fileExists(atPath: (agentSkillDir as NSString).appendingPathComponent("my-skill")))
        #expect(FileManager.default.fileExists(atPath: (agentSkillDir as NSString).appendingPathComponent("skill-2")))
    }

    @Test func batchEnableUngroupedGroup() throws {
        let (sourceId, skillId, agentId, agentSkillDir) = try createFixture()

        try sync.enableGroup(sourceId: sourceId, groupName: "ungrouped", agentId: agentId, agentSkillsDir: agentSkillDir)

        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        #expect(state?.enabled == true)
        #expect(FileManager.default.fileExists(atPath: (agentSkillDir as NSString).appendingPathComponent("my-skill")))
    }
}
