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
        let normalized = normalizeInput(inputPath)
        let sourceType = SourceParser.parse(normalized)

        // Resolve scan path first (clone if git) so failures don't leave stale DB records
        let scanPath: String
        var tempDir: String?
        let rootSkillName: String?

        switch sourceType {
        case .git(let url):
            let cloneDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("skillhub-clone-\(UUID().uuidString)").path
            try cloneGit(url: url, to: cloneDir)
            tempDir = cloneDir
            scanPath = cloneDir
            rootSkillName = sourceName
        case .local(let path):
            scanPath = path
            rootSkillName = nil
        case .npm:
            throw SkillServiceError.unsupportedSource("npm packages are not yet supported")
        case nil:
            throw SkillServiceError.invalidSource("unable to determine source type for: \(normalized)")
        }

        defer {
            if let dir = tempDir { try? FileManager.default.removeItem(atPath: dir) }
        }

        let discoveredSkills = findInternalSkills(at: scanPath, rootSkillName: rootSkillName)

        // Prepare local store
        let targetDir = (skillsStorePath as NSString)
            .appendingPathComponent(sourceName)
        try? FileManager.default.removeItem(atPath: targetDir)
        try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        // Insert source + skills in DB
        var source = Source(name: sourceName, label: sourceLabel, origin: normalized, installedAt: Date())
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
            try Skill.filter(Skill.Columns.sourceId == source.id).deleteAll(db)

            for skill in discoveredSkills {
                let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
                var record = Skill(
                    name: skill.name,
                    sourceId: source.id,
                    installPath: destPath,
                    description: skill.description,
                    groups: skill.groups,
                    version: nil,
                    installedAt: Date(),
                    updatedAt: Date()
                )
                try record.insert(db)
            }
        }

        // Copy skill files to local store (after DB commit)
        for skill in discoveredSkills {
            let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
            try FileManager.default.copyItem(atPath: skill.path, toPath: destPath)
        }

        return source
    }

    func confirmInstall(resolved: ResolvedSource, sourceName: String, sourceLabel: String, selectedSkills: [DiscoveredSkill]) throws -> Source {
        let targetDir = (skillsStorePath as NSString)
            .appendingPathComponent(sourceName)
        try? FileManager.default.removeItem(atPath: targetDir)
        try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        var source = Source(name: sourceName, label: sourceLabel, origin: resolved.originalInput, installedAt: Date())
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
            try Skill.filter(Skill.Columns.sourceId == source.id).deleteAll(db)

            for skill in selectedSkills {
                let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
                var record = Skill(
                    name: skill.name,
                    sourceId: source.id,
                    installPath: destPath,
                    description: skill.description,
                    groups: skill.groups,
                    version: nil,
                    installedAt: Date(),
                    updatedAt: Date()
                )
                try record.insert(db)

                // Copy from the discovered skill path (already resolved by preview)
                try FileManager.default.copyItem(atPath: skill.path, toPath: destPath)
            }
        }

        return source
    }

    // MARK: - Git clone

    private func normalizeInput(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        // URLs: keep as-is — expandingTildeInPath mangles double slashes
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://")
            || trimmed.hasPrefix("git@") || trimmed.hasPrefix("ssh://") {
            return trimmed
        }
        // npm packages: keep as-is
        if trimmed.hasPrefix("@") && trimmed.contains("/") {
            return trimmed
        }
        // Local paths: expand tilde
        return (trimmed as NSString).expandingTildeInPath
    }

    private func cloneGit(url: String, to path: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["git", "clone", "--depth", "1", url, path]

        let errorPipe = Pipe()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
            throw SkillServiceError.gitCloneFailed("git clone failed: \(errorString)")
        }
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

    func refreshDescriptions() throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.description == nil).fetchAll(db)
        }
        for var skill in skills {
            let meta = parseMetadata(from: skill.installPath)
            guard meta.description != nil else { continue }
            skill.description = meta.description
            try database.dbQueue.write { db in
                try skill.update(db)
            }
        }
    }

    func updateSource(_ sourceId: Int64, homeOverride: String? = nil) throws -> Source {
        let source = try database.dbQueue.read { db in
            try Source.fetchOne(db, key: sourceId)
        }
        guard let source = source else {
            throw SkillServiceError.invalidSource("source not found")
        }
        guard SourceParser.parse(source.origin) != nil else {
            throw SkillServiceError.invalidSource("cannot determine source type for update")
        }

        let normalized = source.origin
        let sourceType = SourceParser.parse(normalized)

        let scanPath: String
        var tempDir: String?
        let rootSkillName: String?

        switch sourceType {
        case .git(let url):
            let cloneDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("skillhub-update-\(UUID().uuidString)").path
            try cloneGit(url: url, to: cloneDir)
            tempDir = cloneDir
            scanPath = cloneDir
            rootSkillName = source.name
        case .local(let path):
            scanPath = path
            rootSkillName = nil
        case .npm:
            throw SkillServiceError.unsupportedSource("npm packages are not yet supported")
        case nil:
            throw SkillServiceError.invalidSource("unable to determine source type for: \(normalized)")
        }

        defer {
            if let dir = tempDir { try? FileManager.default.removeItem(atPath: dir) }
        }

        let discoveredSkills = findInternalSkills(at: scanPath, rootSkillName: rootSkillName)

        let targetDir = (skillsStorePath as NSString)
            .appendingPathComponent(source.name)
        try? FileManager.default.removeItem(atPath: targetDir)
        try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        var updatedSource = source
        updatedSource.installedAt = Date()
        try database.dbQueue.write { db in
            try updatedSource.update(db)
            try Skill.filter(Skill.Columns.sourceId == source.id).deleteAll(db)

            for skill in discoveredSkills {
                let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
                var record = Skill(
                    name: skill.name,
                    sourceId: source.id,
                    installPath: destPath,
                    description: skill.description,
                    groups: skill.groups,
                    version: nil,
                    installedAt: Date(),
                    updatedAt: Date()
                )
                try record.insert(db)
            }
        }

        for skill in discoveredSkills {
            let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
            try FileManager.default.copyItem(atPath: skill.path, toPath: destPath)
        }

        let homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
        let syncService = SyncService(database: database, homeOverride: homeOverride)
        let agents = try database.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
        for agent in agents where agent.visible {
            let existingStates = (try? syncService.getAgentSkillStates(agentId: agent.id)) ?? [:]
            let hadSourceSkills = existingStates.values.contains { $0 }
            guard hadSourceSkills else { continue }

            let configPath = agent.configPath
            let skillsDir: String
            if let cp = configPath {
                skillsDir = (cp as NSString).appendingPathComponent("skills")
            } else {
                let def = AgentService.knownAgents.first { $0.name == agent.name }
                let relative = def?.configPaths.first ?? ".claude"
                skillsDir = ((homePath as NSString).appendingPathComponent(relative) as NSString).appendingPathComponent("skills")
            }
            try? FileManager.default.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)

            let updatedSkills = try database.dbQueue.read { db in
                try Skill.filter(Skill.Columns.sourceId == source.id).fetchAll(db)
            }
            for skill in updatedSkills {
                try? syncService.enableSkill(skillId: skill.id, agentId: agent.id, agentSkillsDir: skillsDir)
            }
        }

        return updatedSource
    }

    // MARK: - Preview

    struct DiscoveredSkill {
        let name: String
        let groups: [String]
        let description: String?
        let path: String
    }

    struct ResolvedSource {
        let scanPath: String
        let originalInput: String
        let skills: [DiscoveredSkill]
        var tempDir: String?
    }

    func preview(from inputPath: String) throws -> ResolvedSource {
        let normalized = normalizeInput(inputPath)
        let sourceType = SourceParser.parse(normalized)

        let scanPath: String
        var tempDir: String?
        let rootSkillName: String?

        switch sourceType {
        case .git(let url):
            let cloneDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("skillhub-clone-\(UUID().uuidString)").path
            try cloneGit(url: url, to: cloneDir)
            tempDir = cloneDir
            scanPath = cloneDir
            rootSkillName = suggestedSourceName(from: normalized)
        case .local(let path):
            scanPath = path
            rootSkillName = nil
        case .npm:
            throw SkillServiceError.unsupportedSource("npm packages are not yet supported")
        case nil:
            throw SkillServiceError.invalidSource("unable to determine source type for: \(normalized)")
        }

        let skills = findSkills(at: scanPath, rootSkillName: rootSkillName)
        return ResolvedSource(scanPath: scanPath, originalInput: normalized, skills: skills, tempDir: tempDir)
    }

    // MARK: - Private

    private struct InternalSkill {
        let name: String
        let path: String
        let groups: [String]
        let description: String?
    }

    private func findSkills(at path: String, rootSkillName: String? = nil) -> [DiscoveredSkill] {
        return findInternalSkills(at: path, rootSkillName: rootSkillName).map { DiscoveredSkill(name: $0.name, groups: $0.groups, description: $0.description, path: $0.path) }
    }

    private func findInternalSkills(at path: String, depth: Int = 0, rootSkillName: String? = nil) -> [InternalSkill] {
        var result: [InternalSkill] = []
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            if hasSkillMD(at: path) {
                let name = rootSkillName ?? (path as NSString).lastPathComponent
                let meta = parseMetadata(from: path)
                result.append(InternalSkill(name: name, path: path, groups: meta.groups, description: meta.description))
            }
            return result
        }

        // Skip hidden dirs at depth 0 to avoid scanning .git etc.
        for entry in entries where !entriesToSkip(entry, at: depth) {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            if hasSkillMD(at: fullPath) {
                let meta = parseMetadata(from: fullPath)
                result.append(InternalSkill(name: entry, path: fullPath, groups: meta.groups, description: meta.description))
            } else if depth < 2 {
                result.append(contentsOf: findInternalSkills(at: fullPath, depth: depth + 1))
            }
        }
        // If no subdirectories were found as skills, check if this path itself is a skill
        if result.isEmpty && hasSkillMD(at: path) {
            let name = rootSkillName ?? (path as NSString).lastPathComponent
            let meta = parseMetadata(from: path)
            result.append(InternalSkill(name: name, path: path, groups: meta.groups, description: meta.description))
        }
        return result
    }

    private func suggestedSourceName(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmed.hasPrefix("git@")
            ? trimmed.split(separator: ":").last.map(String.init) ?? trimmed
            : trimmed
        return (path as NSString).lastPathComponent
            .replacingOccurrences(of: ".git", with: "")
    }

    private func entriesToSkip(_ name: String, at depth: Int) -> Bool {
        if name.hasPrefix(".") { return true }
        if depth > 0 { return false }
        let skip = ["node_modules", "packages", "scripts", "screenshots", "docs", "tests", "__pycache__"]
        return skip.contains(name)
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

    private func parseMetadata(from path: String) -> (groups: [String], description: String?) {
        let skillMDPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOfFile: skillMDPath, encoding: .utf8),
              content.hasPrefix("---") else {
            return ([], nil)
        }
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else { return ([], nil) }
        let frontmatter = parts[1]
        var groups: [String] = []
        var description: String? = nil
        for line in frontmatter.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("groups:") || trimmed.hasPrefix("group:") {
                let values = trimmed.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                groups = values.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "[]\"'")) }
                    .filter { !$0.isEmpty }
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return (groups, description)
    }
}

enum SkillServiceError: LocalizedError {
    case gitCloneFailed(String)
    case unsupportedSource(String)
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .gitCloneFailed(let msg): return msg
        case .unsupportedSource(let msg): return msg
        case .invalidSource(let msg): return msg
        }
    }
}
