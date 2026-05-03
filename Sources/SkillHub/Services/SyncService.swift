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

        let destPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        try removeIfManaged(atPath: destPath)
        try FileManager.default.createDirectory(atPath: agentSkillsDir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: skill.installPath, toPath: destPath)

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

        let destPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        try removeIfManaged(atPath: destPath)

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

    private func removeIfManaged(atPath path: String) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }

        // Symlink: always remove (legacy or managed)
        if !isDir.boolValue {
            if let _ = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
                return
            }
            throw SyncError.unmanagedPathExists(path: path)
        }

        // Directory: check if it looks like a SkillHub copy (contains SKILL.md or .skillhub-source marker)
        let markerPath = (path as NSString).appendingPathComponent(".skillhub-source")
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        let hasMarker = FileManager.default.fileExists(atPath: markerPath)
        let hasSkillMd = FileManager.default.fileExists(atPath: skillMdPath)

        if hasMarker || hasSkillMd {
            try FileManager.default.removeItem(atPath: path)
            return
        }

        throw SyncError.unmanagedPathExists(path: path)
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
    case unmanagedPathExists(path: String)

    var errorDescription: String? {
        switch self {
        case .skillNotFound: return "Skill not found in database"
        case .unmanagedPathExists(let path):
            return "A non-SkillHub item already exists at \(path)"
        }
    }
}
