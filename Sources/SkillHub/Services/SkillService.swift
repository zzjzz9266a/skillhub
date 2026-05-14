import GRDB
import Foundation

final class SkillService {
    let database: DatabaseService
    let skillsStorePath: String
    private let gitCloner: (String, String) throws -> Void
    private let skillsCLIImporter: (String, String) throws -> Void

    init(
        database: DatabaseService,
        skillsStorePath: String? = nil,
        gitCloner: @escaping (String, String) throws -> Void = SkillService.defaultGitCloner,
        skillsCLIImporter: @escaping (String, String) throws -> Void = SkillService.defaultSkillsCLIImporter
    ) {
        self.database = database
        self.gitCloner = gitCloner
        self.skillsCLIImporter = skillsCLIImporter
        if let path = skillsStorePath {
            self.skillsStorePath = path
        } else {
            self.skillsStorePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".skillhub/skills").path
        }
    }

    func install(from inputPath: String, sourceName: String, sourceLabel: String) throws -> Source {
        let resolved = try resolveSource(from: inputPath, gitRootSkillName: sourceName)
        defer { cleanupResolvedSource(resolved) }
        return try confirmInstall(
            resolved: resolved,
            sourceName: sourceName,
            sourceLabel: sourceLabel,
            selectedSkills: resolved.skills
        )
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

    static func defaultGitCloner(url: String, path: String) throws {
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

    static func defaultSkillsCLIImporter(source: String, workspace: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["npx", "-y", "skills", "add", source, "-a", "claude-code", "--copy", "-y"]
        task.currentDirectoryURL = URL(fileURLWithPath: workspace)

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
            throw SkillServiceError.skillImportFailed("npx skills import failed: \(output)")
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
            try Skill.fetchAll(db)
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

        let resolved = try resolveSource(from: source.origin, gitRootSkillName: source.name)
        defer { cleanupResolvedSource(resolved) }
        let discoveredSkills = resolved.skills

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
        try resolveSource(from: inputPath)
    }

    // MARK: - Private

    private struct InternalSkill {
        let name: String
        let path: String
        let groups: [String]
        let description: String?
    }

    private let skillCollectionDirectoryNames: Set<String> = ["skills"]
    private let readmeCandidates: [String] = ["README.md", "readme.md"]
    private let installerSkillsRelativePath = ".claude/skills"

    private func resolveSource(from inputPath: String, gitRootSkillName: String? = nil) throws -> ResolvedSource {
        let normalized = normalizeInput(inputPath)
        let sourceType = SourceParser.parse(normalized)

        switch sourceType {
        case .git(let url):
            let tempDir = try createTemporaryDirectory(prefix: "skillhub-source")
            let cloneDir = (tempDir as NSString).appendingPathComponent("repo")
            try gitCloner(url, cloneDir)

            let rootSkillName = gitRootSkillName ?? suggestedSourceName(from: normalized)
            let skills = resolveGitRepositorySkills(
                repositoryPath: cloneDir,
                originalInput: normalized,
                rootSkillName: rootSkillName,
                tempDir: tempDir
            )
            return ResolvedSource(scanPath: cloneDir, originalInput: normalized, skills: skills, tempDir: tempDir)
        case .local(let path):
            let skills = findSkills(at: path)
            return ResolvedSource(scanPath: path, originalInput: normalized, skills: skills, tempDir: nil)
        case .npm:
            throw SkillServiceError.unsupportedSource("npm packages are not yet supported")
        case nil:
            throw SkillServiceError.invalidSource("unable to determine source type for: \(normalized)")
        }
    }

    private func resolveGitRepositorySkills(
        repositoryPath: String,
        originalInput: String,
        rootSkillName: String,
        tempDir: String
    ) -> [DiscoveredSkill] {
        guard repositoryAdvertisesSkillsInstaller(at: repositoryPath) else {
            return findSkills(at: repositoryPath, rootSkillName: rootSkillName)
        }

        let installerWorkspace = (tempDir as NSString).appendingPathComponent("installer")
        do {
            try FileManager.default.createDirectory(atPath: installerWorkspace, withIntermediateDirectories: true)
            try skillsCLIImporter(originalInput, installerWorkspace)
            return try discoverImportedSkills(
                installerWorkspace: installerWorkspace,
                repositoryPath: repositoryPath
            )
        } catch {
            return findSkills(at: repositoryPath, rootSkillName: rootSkillName)
        }
    }

    private func findSkills(at path: String, rootSkillName: String? = nil) -> [DiscoveredSkill] {
        return findInternalSkills(at: path, rootSkillName: rootSkillName).map { DiscoveredSkill(name: $0.name, groups: $0.groups, description: $0.description, path: $0.path) }
    }

    private func findInternalSkills(at path: String, rootSkillName: String? = nil) -> [InternalSkill] {
        if hasSkillMD(at: path) {
            return [buildInternalSkill(at: path, name: rootSkillName ?? (path as NSString).lastPathComponent)]
        }

        let childDirectories = subdirectories(at: path)
        guard !childDirectories.isEmpty else {
            return []
        }

        var discovered = childDirectories.compactMap { entry -> InternalSkill? in
            let fullPath = (path as NSString).appendingPathComponent(entry)
            guard hasSkillMD(at: fullPath) else { return nil }
            return buildInternalSkill(at: fullPath, name: entry)
        }

        let supportsStableCollectionLayout = repositoryAdvertisesSkillsInstaller(at: path)

        for entry in childDirectories where skillCollectionDirectoryNames.contains(entry) && supportsStableCollectionLayout {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            discovered.append(contentsOf: findSkillsInCollectionDirectory(at: fullPath))
        }

        var seenPaths: Set<String> = []
        return discovered
            .filter { seenPaths.insert($0.path).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func findSkillsInCollectionDirectory(at path: String) -> [InternalSkill] {
        let childDirectories = subdirectories(at: path)
        var discovered: [InternalSkill] = []

        for entry in childDirectories {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            if hasSkillMD(at: fullPath) {
                discovered.append(buildInternalSkill(at: fullPath, name: entry))
                continue
            }

            for nestedEntry in subdirectories(at: fullPath) {
                let nestedPath = (fullPath as NSString).appendingPathComponent(nestedEntry)
                guard hasSkillMD(at: nestedPath) else { continue }
                discovered.append(buildInternalSkill(at: nestedPath, name: nestedEntry, defaultGroups: [entry]))
            }
        }

        return discovered
    }

    private func buildInternalSkill(at path: String, name: String, defaultGroups: [String] = []) -> InternalSkill {
        let meta = parseMetadata(from: path)
        let groups = meta.groups.isEmpty ? defaultGroups : meta.groups
        return InternalSkill(name: name, path: path, groups: groups, description: meta.description)
    }

    private func discoverImportedSkills(
        installerWorkspace: String,
        repositoryPath: String
    ) throws -> [DiscoveredSkill] {
        let installedSkillsPath = (installerWorkspace as NSString).appendingPathComponent(installerSkillsRelativePath)
        let inferredGroups = inferredGroupsBySkillName(from: repositoryPath)
        let discovered = subdirectories(at: installedSkillsPath)
            .compactMap { entry -> DiscoveredSkill? in
                let fullPath = (installedSkillsPath as NSString).appendingPathComponent(entry)
                guard hasSkillMD(at: fullPath) else { return nil }
                let skill = buildInternalSkill(at: fullPath, name: entry, defaultGroups: inferredGroups[entry] ?? [])
                return DiscoveredSkill(
                    name: skill.name,
                    groups: skill.groups,
                    description: skill.description,
                    path: skill.path
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard !discovered.isEmpty else {
            throw SkillServiceError.skillImportFailed("npx skills import did not produce any installed skills")
        }

        return discovered
    }

    private func inferredGroupsBySkillName(from repositoryPath: String) -> [String: [String]] {
        var groupsBySkillName: [String: Set<String>] = [:]

        for entry in subdirectories(at: repositoryPath) where skillCollectionDirectoryNames.contains(entry) {
            let collectionPath = (repositoryPath as NSString).appendingPathComponent(entry)
            for skill in findSkillsInCollectionDirectory(at: collectionPath) {
                let existing = groupsBySkillName[skill.name] ?? []
                groupsBySkillName[skill.name] = existing.union(skill.groups)
            }
        }

        return groupsBySkillName.mapValues { groups in
            groups.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }

    private func subdirectories(at path: String) -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return []
        }

        return entries
            .filter { !$0.hasPrefix(".") }
            .filter { entry in
                let fullPath = (path as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
            }
    }

    private func repositoryAdvertisesSkillsInstaller(at path: String) -> Bool {
        for candidate in readmeCandidates {
            let readmePath = (path as NSString).appendingPathComponent(candidate)
            guard FileManager.default.fileExists(atPath: readmePath),
                  let content = try? String(contentsOfFile: readmePath, encoding: .utf8) else {
                continue
            }
            if content.localizedCaseInsensitiveContains("skills.sh") {
                return true
            }
            if content.range(
                of: #"(?i)\bnpx(?:\s+-\S+)*\s+skills(?:@[A-Za-z0-9._-]+)?\b"#,
                options: .regularExpression
            ) != nil {
                return true
            }
        }
        return false
    }

    private func createTemporaryDirectory(prefix: String) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func cleanupResolvedSource(_ resolved: ResolvedSource) {
        if let dir = resolved.tempDir {
            try? FileManager.default.removeItem(atPath: dir)
        }
    }

    private func suggestedSourceName(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmed.hasPrefix("git@")
            ? trimmed.split(separator: ":").last.map(String.init) ?? trimmed
            : trimmed
        return (path as NSString).lastPathComponent
            .replacingOccurrences(of: ".git", with: "")
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
        let lines = frontmatter.components(separatedBy: "\n")
        var groups: [String] = []
        var description: String? = nil
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("groups:") || trimmed.hasPrefix("group:") {
                let values = trimmed.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                groups = values.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "[]\"'")) }
                    .filter { !$0.isEmpty }
            } else if trimmed.hasPrefix("description:") {
                let afterColon = trimmed.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if afterColon == "|" || afterColon == ">" {
                    let indicator = afterColon
                    var blockLines: [String] = []
                    let baseIndent: Int = {
                        if i + 1 < lines.count {
                            let nextLine = lines[i + 1]
                            let leading = nextLine.prefix(while: { $0 == " " || $0 == "\t" })
                            return leading.count
                        }
                        return 0
                    }()
                    i += 1
                    while i < lines.count {
                        let line = lines[i]
                        let leading = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                        let stripped = line.trimmingCharacters(in: .whitespaces)
                        if stripped.isEmpty { blockLines.append("") }
                        else if leading >= baseIndent { blockLines.append(String(line.dropFirst(min(leading, baseIndent)))) }
                        else { break }
                        i += 1
                    }
                    if indicator == "|" {
                        description = blockLines.joined(separator: "\n")
                    } else {
                        description = blockLines.map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                    }
                    continue
                } else if afterColon.hasPrefix(">") {
                    let foldedRest = afterColon.dropFirst().trimmingCharacters(in: .whitespaces)
                    if foldedRest.isEmpty {
                        var blockLines: [String] = []
                        let baseIndent: Int = {
                            if i + 1 < lines.count {
                                let nextLine = lines[i + 1]
                                let leading = nextLine.prefix(while: { $0 == " " || $0 == "\t" })
                                return leading.count
                            }
                            return 0
                        }()
                        i += 1
                        while i < lines.count {
                            let line = lines[i]
                            let leading = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                            let stripped = line.trimmingCharacters(in: .whitespaces)
                            if stripped.isEmpty { blockLines.append("") }
                            else if leading >= baseIndent { blockLines.append(String(line.dropFirst(min(leading, baseIndent)))) }
                            else { break }
                            i += 1
                        }
                        description = blockLines.map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                    } else {
                        description = foldedRest
                    }
                } else {
                    description = afterColon.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
            i += 1
        }
        return (groups, description)
    }
}

enum SkillServiceError: LocalizedError {
    case gitCloneFailed(String)
    case skillImportFailed(String)
    case unsupportedSource(String)
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .gitCloneFailed(let msg): return msg
        case .skillImportFailed(let msg): return msg
        case .unsupportedSource(let msg): return msg
        case .invalidSource(let msg): return msg
        }
    }
}
