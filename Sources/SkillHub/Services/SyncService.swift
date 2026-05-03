import GRDB
import Foundation

final class SyncService {
    let database: DatabaseService
    let homePath: String
    static let skillHubMarker = ".skillhub-managed"

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
        let markerPath = (destPath as NSString).appendingPathComponent(SyncService.skillHubMarker)
        try Data().write(to: URL(fileURLWithPath: markerPath))

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

        // Symlink: always remove (legacy from previous versions)
        if !isDir.boolValue {
            if let _ = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
                return
            }
            throw SyncError.unmanagedPathExists(path: path)
        }

        // Directory: only remove if it has our marker file
        let markerPath = (path as NSString).appendingPathComponent(Self.skillHubMarker)
        if FileManager.default.fileExists(atPath: markerPath) {
            try FileManager.default.removeItem(atPath: path)
            return
        }

        // Legacy: no marker but has SKILL.md (from previous symlink-based versions)
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: skillMdPath) {
            let destPath = path
            try FileManager.default.removeItem(atPath: destPath)
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
