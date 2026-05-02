import GRDB
import Foundation

final class SyncService {
    let database: DatabaseService
    let homePath: String

    init(database: DatabaseService, homeOverride: String? = nil) {
        self.database = database
        self.homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    func enableSkill(skillId: Int64, agentId: Int64, agentSkillsDir: String) throws {
        guard let skill = try database.dbQueue.read({ db in
            try Skill.filter(Skill.Columns.id == skillId).fetchOne(db)
        }) else {
            throw SyncError.skillNotFound
        }

        let linkPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        if FileManager.default.fileExists(atPath: linkPath) {
            try FileManager.default.removeItem(atPath: linkPath)
        }
        try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: skill.installPath)

        let agentSkill = AgentSkill(agentId: agentId, skillId: skillId, enabled: true)
        try database.dbQueue.write { db in
            try agentSkill.save(db)
        }
    }

    func disableSkill(skillId: Int64, agentId: Int64, agentSkillsDir: String) throws {
        guard let skill = try database.dbQueue.read({ db in
            try Skill.filter(Skill.Columns.id == skillId).fetchOne(db)
        }) else {
            throw SyncError.skillNotFound
        }

        let linkPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        if FileManager.default.fileExists(atPath: linkPath) {
            try FileManager.default.removeItem(atPath: linkPath)
        }

        let agentSkill = AgentSkill(agentId: agentId, skillId: skillId, enabled: false)
        try database.dbQueue.write { db in
            try agentSkill.save(db)
        }
    }

    func enableSource(sourceId: Int64, agentId: Int64, agentSkillsDir: String) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        for skill in skills {
            do {
                try enableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                print("Failed to enable \(skill.name): \(error)")
            }
        }
    }

    func enableGroup(sourceId: Int64, groupName: String, agentId: Int64, agentSkillsDir: String) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        let groupedSkills = skills.filter { $0.belongsToGroup(groupName) }
        for skill in groupedSkills {
            do {
                try enableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                print("Failed to enable \(skill.name): \(error)")
            }
        }
    }

    func disableSource(sourceId: Int64, agentId: Int64, agentSkillsDir: String) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        for skill in skills {
            do {
                try disableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                print("Failed to disable \(skill.name): \(error)")
            }
        }
    }

    func disableGroup(sourceId: Int64, groupName: String, agentId: Int64, agentSkillsDir: String) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        let groupedSkills = skills.filter { $0.belongsToGroup(groupName) }
        for skill in groupedSkills {
            do {
                try disableSkill(skillId: skill.id, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                print("Failed to disable \(skill.name): \(error)")
            }
        }
    }

    func getAgentSkillStates(agentId: Int64) throws -> [Int64: Bool] {
        let records = try database.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId).fetchAll(db)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.skillId, $0.enabled) })
    }
}

private extension Skill {
    func belongsToGroup(_ groupName: String) -> Bool {
        if groups.isEmpty {
            return groupName == "ungrouped"
        }
        return groups.contains(groupName)
    }
}

enum SyncError: LocalizedError {
    case skillNotFound

    var errorDescription: String? {
        switch self {
        case .skillNotFound: return "Skill not found in database"
        }
    }
}
