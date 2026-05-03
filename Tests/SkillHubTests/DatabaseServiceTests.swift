import Foundation
import Testing
import GRDB
@testable import SkillHub

struct DatabaseServiceTests {
    let db: DatabaseService

    init() throws {
        db = try DatabaseService(inMemory: true)
    }

    @Test func insertAndFetchSource() throws {
        var source = Source(id: 0, name: "superpowers", label: "Superpowers", origin: "https://github.com/obra/superpowers.git", installedAt: Date())
        try db.dbQueue.write { db in
            try source.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Source.fetchAll(db)
        }
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "superpowers")
        #expect(fetched.first?.label == "Superpowers")
    }

    @Test func insertAndFetchSkill() throws {
        var source = Source(id: 0, name: "test", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in
            try source.insert(db)
        }
        var skill = Skill(id: 0, name: "brainstorming", sourceId: source.id, installPath: "/tmp/test", groups: ["gsd"], version: "1.0", installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in
            try skill.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Skill.fetchAll(db)
        }
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "brainstorming")
        #expect(fetched.first?.groups == ["gsd"])
    }

    @Test func insertAndFetchAgent() throws {
        var agent = Agent(id: 0, name: "Claude Code", configPath: "~/.claude/", detectedAt: Date(), hotReloadSupported: true, visible: true, installed: true)
        try db.dbQueue.write { db in
            try agent.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Claude Code")
        #expect(fetched.first?.hotReloadSupported ?? false)
    }

    @Test func agentSkillToggle() throws {
        var source = Source(id: 0, name: "test", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in try source.insert(db) }
        var skill = Skill(id: 0, name: "test-skill", sourceId: source.id, installPath: "/tmp/test", groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill.insert(db) }
        var agent = Agent(id: 0, name: "TestAgent", configPath: nil, detectedAt: Date(), hotReloadSupported: true, visible: true, installed: true)
        try db.dbQueue.write { db in try agent.insert(db) }

        var agentSkill = AgentSkill(agentId: agent.id, skillId: skill.id, enabled: true)
        try db.dbQueue.write { db in try agentSkill.save(db) }

        let states = try db.dbQueue.read { db in
            try AgentSkill.fetchAll(db)
        }
        #expect(states.count == 1)
        #expect(states.first?.enabled ?? false)

        agentSkill.enabled = false
        try db.dbQueue.write { db in try agentSkill.save(db) }

        let updated = try db.dbQueue.read { db in
            try AgentSkill.fetchAll(db)
        }
        #expect(!(updated.first?.enabled ?? true))
    }
}
