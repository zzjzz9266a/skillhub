import GRDB
import Foundation

final class SkillService {
    let database: DatabaseService
    let skillsStorePath: String

    init(database: DatabaseService, skillsStorePath: String? = nil) {
        self.database = database
        if let path = skillsStorePath {
            self.skillsStorePath = path
        } else {
            self.skillsStorePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".skillhub/skills").path
        }
    }

    func install(from inputPath: String, sourceName: String, sourceLabel: String) throws -> Source {
        let expanded = (inputPath as NSString).expandingTildeInPath

        var source = Source(name: sourceName, label: sourceLabel, origin: expanded, installedAt: Date())
        try database.dbQueue.write { db in
            if let existing = try Source.filter(Source.Columns.name == sourceName).fetchOne(db) {
                source.id = existing.id
                try source.update(db)
            } else {
                try source.insert(db)
            }
            if source.id == 0 {
                source = try Source.filter(Source.Columns.name == sourceName).fetchOne(db)!
            }
        }

        let targetDir = (skillsStorePath as NSString)
            .appendingPathComponent(sourceName)
        try? FileManager.default.removeItem(atPath: targetDir)
        try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        let discoveredSkills = findSkills(at: expanded)

        for skill in discoveredSkills {
            let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
            try FileManager.default.copyItem(atPath: skill.path, toPath: destPath)

            let record = Skill(
                name: skill.name,
                sourceId: source.id,
                installPath: destPath,
                groups: skill.groups,
                version: nil,
                installedAt: Date(),
                updatedAt: Date()
            )
            try database.dbQueue.write { db in
                try record.insert(db)
            }
        }

        return source
    }

    func getSource(by name: String) throws -> Source? {
        return try database.dbQueue.read { db in
            try Source.filter(Source.Columns.name == name).fetchOne(db)
        }
    }

    func deleteSource(_ sourceId: Int64) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        for skill in skills {
            try? FileManager.default.removeItem(atPath: skill.installPath)
        }
        try database.dbQueue.write { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).deleteAll(db)
            try Source.filter(Source.Columns.id == sourceId).deleteAll(db)
        }
    }

    // MARK: - Private

    private struct DiscoveredSkill {
        let name: String
        let path: String
        let groups: [String]
    }

    private func findSkills(at path: String) -> [DiscoveredSkill] {
        var result: [DiscoveredSkill] = []
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            if hasSkillMD(at: path) {
                let name = (path as NSString).lastPathComponent
                let groups = parseGroups(from: path)
                result.append(DiscoveredSkill(name: name, path: path, groups: groups))
            }
            return result
        }

        for entry in entries {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            if hasSkillMD(at: fullPath) {
                let groups = parseGroups(from: fullPath)
                result.append(DiscoveredSkill(name: entry, path: fullPath, groups: groups))
            }
        }
        return result
    }

    private func hasSkillMD(at path: String) -> Bool {
        let candidates = ["SKILL.md", "skill.md"]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(candidate)) {
                return true
            }
        }
        return false
    }

    private func parseGroups(from path: String) -> [String] {
        let skillMDPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOfFile: skillMDPath, encoding: .utf8) else {
            return []
        }
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                for line in frontmatter.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("groups:") || trimmed.hasPrefix("group:") {
                        let values = trimmed.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                        let items = values.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "[]\"'")) }
                            .filter { !$0.isEmpty }
                        return items
                    }
                }
            }
        }
        return []
    }
}
