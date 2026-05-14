import Foundation
import Testing
import GRDB
@testable import SkillHub

struct SkillServiceTests {
    let db: DatabaseService
    let service: SkillService
    let tempDir: String

    init() throws {
        db = try DatabaseService(inMemory: true)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        service = SkillService(database: db, skillsStorePath: tempDir)
    }

    private func makeService(
        gitCloner: @escaping (String, String) throws -> Void = { url, path in
            try SkillService.defaultGitCloner(url: url, path: path)
        },
        skillsCLIImporter: @escaping (String, String) throws -> Void = { source, workspace in
            try SkillService.defaultSkillsCLIImporter(source: source, workspace: workspace)
        }
    ) -> SkillService {
        SkillService(
            database: db,
            skillsStorePath: tempDir,
            gitCloner: gitCloner,
            skillsCLIImporter: skillsCLIImporter
        )
    }

    @Test func installLocalSkill() throws {
        let skillDir = (tempDir as NSString).appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
        let skillMD = (skillDir as NSString).appendingPathComponent("SKILL.md")
        try "# Test Skill\nA test skill for unit testing".write(toFile: skillMD, atomically: true, encoding: .utf8)

        let source = try service.install(from: skillDir, sourceName: "test-source", sourceLabel: "Test Source")
        #expect(source.name == "test-source")

        let sources = try db.dbQueue.read { db in try Source.fetchAll(db) }
        #expect(sources.count == 1)

        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        #expect(skills.count == 1)
        #expect(skills.first?.name == "test-skill")

        let installedPath = skills.first!.installPath
        #expect(FileManager.default.fileExists(atPath: installedPath))
        #expect(FileManager.default.fileExists(
            atPath: (installedPath as NSString).appendingPathComponent("SKILL.md")))
    }

    @Test func installMultipleSkillsInDirectory() throws {
        let sourceDir = (tempDir as NSString).appendingPathComponent("multi-skill-source")
        try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)

        let skillADir = (sourceDir as NSString).appendingPathComponent("skill-a")
        try FileManager.default.createDirectory(atPath: skillADir, withIntermediateDirectories: true)
        try "# Skill A".write(toFile: (skillADir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let skillBDir = (sourceDir as NSString).appendingPathComponent("skill-b")
        try FileManager.default.createDirectory(atPath: skillBDir, withIntermediateDirectories: true)
        try "# Skill B".write(toFile: (skillBDir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let nonSkillDir = (sourceDir as NSString).appendingPathComponent("not-a-skill")
        try FileManager.default.createDirectory(atPath: nonSkillDir, withIntermediateDirectories: true)

        _ = try service.install(from: sourceDir, sourceName: "multi", sourceLabel: "Multi Skill Source")

        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        #expect(skills.count == 2, "Only directories with SKILL.md should be counted as skills")
        let names = skills.map { $0.name }.sorted()
        #expect(names == ["skill-a", "skill-b"])
    }

    @Test func reinstallSameSourceReplacesOldSkills() throws {
        let sourceDir = (tempDir as NSString).appendingPathComponent("replace-source")
        try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)

        let oldSkillDir = (sourceDir as NSString).appendingPathComponent("old-skill")
        try FileManager.default.createDirectory(atPath: oldSkillDir, withIntermediateDirectories: true)
        try "# Old Skill".write(toFile: (oldSkillDir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        _ = try service.install(from: sourceDir, sourceName: "replace", sourceLabel: "Replace")

        try FileManager.default.removeItem(atPath: oldSkillDir)
        let newSkillDir = (sourceDir as NSString).appendingPathComponent("new-skill")
        try FileManager.default.createDirectory(atPath: newSkillDir, withIntermediateDirectories: true)
        try "# New Skill".write(toFile: (newSkillDir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        _ = try service.install(from: sourceDir, sourceName: "replace", sourceLabel: "Replace")

        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        #expect(skills.map(\.name) == ["new-skill"])
    }

    @Test func previewGitRepoWithRootSkillUsesRepositoryName() throws {
        let repoPath = (tempDir as NSString).appendingPathComponent("friendly-skill.git")
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        try "# Friendly Skill".write(
            toFile: (repoPath as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["init"], in: repoPath)
        try runGit(["add", "SKILL.md"], in: repoPath)
        try runGit([
            "-c", "user.name=SkillHub Tests",
            "-c", "user.email=tests@example.invalid",
            "commit", "-m", "Add skill"
        ], in: repoPath)

        let resolved = try service.preview(from: repoPath)
        defer {
            if let dir = resolved.tempDir {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        #expect(resolved.skills.map(\.name) == ["friendly-skill"])
    }

    @Test func previewRootSkillIgnoresNestedExampleSkills() throws {
        let repoPath = (tempDir as NSString).appendingPathComponent("nuwa-like-skill")
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        try "# Root Skill".write(
            toFile: (repoPath as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let examplesDir = (repoPath as NSString).appendingPathComponent("examples/example-skill")
        try FileManager.default.createDirectory(atPath: examplesDir, withIntermediateDirectories: true)
        try "# Example Skill".write(
            toFile: (examplesDir as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let resolved = try service.preview(from: repoPath)
        defer {
            if let dir = resolved.tempDir {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        #expect(resolved.skills.map(\.name) == ["nuwa-like-skill"])
    }

    @Test func previewGitRepoUsesSkillsInstallerWhenReadmeAdvertisesIt() throws {
        let repoPath = try createGitRepo(
            named: "installer-source.git",
            files: [
                "README.md": """
                # Installer Source

                npx skills@latest add example/installer-source
                """
            ]
        )

        final class ImporterState {
            var calls = 0
        }
        let state = ImporterState()
        let service = makeService(skillsCLIImporter: { _, workspace in
            state.calls += 1
            let skillDir = (workspace as NSString).appendingPathComponent(".claude/skills/diagnose")
            try FileManager.default.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
            try """
            ---
            description: Diagnose things
            ---
            """.write(
                toFile: (skillDir as NSString).appendingPathComponent("SKILL.md"),
                atomically: true,
                encoding: .utf8
            )
        })

        let resolved = try service.preview(from: repoPath)
        defer {
            if let dir = resolved.tempDir {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        #expect(state.calls == 1)
        #expect(resolved.skills.map(\.name) == ["diagnose"])
    }

    @Test func previewGitRepoFallsBackWhenSkillsInstallerFails() throws {
        let repoPath = try createGitRepo(
            named: "fallback-skill.git",
            files: [
                "README.md": """
                # Fallback Skill

                npx skills@latest add example/fallback-skill
                """,
                "SKILL.md": "# Fallback Skill"
            ]
        )

        let service = makeService(skillsCLIImporter: { _, _ in
            throw SkillServiceError.skillImportFailed("simulated importer failure")
        })

        let resolved = try service.preview(from: repoPath)
        defer {
            if let dir = resolved.tempDir {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        #expect(resolved.skills.map(\.name) == ["fallback-skill"])
    }

    @Test func previewGitRepoWithoutInstallerSignalDoesNotRunSkillsInstaller() throws {
        let repoPath = try createGitRepo(
            named: "plain-root-skill.git",
            files: [
                "README.md": "# Plain Root Skill",
                "SKILL.md": "# Plain Root Skill"
            ]
        )

        final class ImporterState {
            var calls = 0
        }
        let state = ImporterState()
        let service = makeService(skillsCLIImporter: { _, _ in
            state.calls += 1
        })

        let resolved = try service.preview(from: repoPath)
        defer {
            if let dir = resolved.tempDir {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }

        #expect(state.calls == 0)
        #expect(resolved.skills.map(\.name) == ["plain-root-skill"])
    }

    @Test func installSkillCollectionParsesBucketFoldersAsGroups() throws {
        let sourceDir = (tempDir as NSString).appendingPathComponent("bucketed-skills")
        let engineeringSkillDir = (sourceDir as NSString).appendingPathComponent("skills/engineering/tdd")
        let productivitySkillDir = (sourceDir as NSString).appendingPathComponent("skills/productivity/handoff")
        try FileManager.default.createDirectory(atPath: engineeringSkillDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: productivitySkillDir, withIntermediateDirectories: true)
        try """
        # Bucketed Skills

        Install with:

        npx skills@latest add example/bucketed-skills
        """.write(
            toFile: (sourceDir as NSString).appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# TDD".write(
            toFile: (engineeringSkillDir as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Handoff".write(
            toFile: (productivitySkillDir as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        _ = try service.install(from: sourceDir, sourceName: "bucketed", sourceLabel: "Bucketed Skills")

        let skills = try db.dbQueue.read { db in
            try Skill.fetchAll(db).sorted { $0.name < $1.name }
        }

        #expect(skills.map(\.name) == ["handoff", "tdd"])
        #expect(skills.map(\.groups) == [["productivity"], ["engineering"]])
    }

    @Test func installGitRepoSkillsInstallerPreservesInferredGroups() throws {
        let repoPath = try createGitRepo(
            named: "bucketed-installer.git",
            files: [
                "README.md": """
                # Bucketed Installer

                npx skills@latest add example/bucketed-installer
                """,
                "skills/engineering/tdd/SKILL.md": "# TDD"
            ]
        )

        let service = makeService(skillsCLIImporter: { _, workspace in
            let skillDir = (workspace as NSString).appendingPathComponent(".claude/skills/tdd")
            try FileManager.default.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
            try """
            ---
            description: Test first
            ---
            """.write(
                toFile: (skillDir as NSString).appendingPathComponent("SKILL.md"),
                atomically: true,
                encoding: .utf8
            )
        })

        _ = try service.install(from: repoPath, sourceName: "bucketed-installer", sourceLabel: "Bucketed Installer")

        let skills = try db.dbQueue.read { db in
            try Skill.fetchAll(db)
        }

        #expect(skills.count == 1)
        #expect(skills.first?.name == "tdd")
        #expect(skills.first?.groups == ["engineering"])
    }

    @Test func installSkillCollectionWithoutNPXReadmeHintDoesNotParseBuckets() throws {
        let sourceDir = (tempDir as NSString).appendingPathComponent("bucketed-skills-no-readme-hint")
        let engineeringSkillDir = (sourceDir as NSString).appendingPathComponent("skills/engineering/tdd")
        try FileManager.default.createDirectory(atPath: engineeringSkillDir, withIntermediateDirectories: true)
        try "# TDD".write(
            toFile: (engineeringSkillDir as NSString).appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Bucketed Skills".write(
            toFile: (sourceDir as NSString).appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

        _ = try service.install(from: sourceDir, sourceName: "bucketed-no-hint", sourceLabel: "Bucketed No Hint")

        let skills = try db.dbQueue.read { db in
            try Skill.fetchAll(db)
        }

        #expect(skills.isEmpty)
    }

    @Test func getExistingSource() throws {
        let sourcePath = (tempDir as NSString).appendingPathComponent("exist-source")
        try FileManager.default.createDirectory(atPath: sourcePath, withIntermediateDirectories: true)
        try "".write(toFile: (sourcePath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        _ = try service.install(from: sourcePath, sourceName: "existing", sourceLabel: "Existing")

        let source = try service.getSource(by: "existing")
        #expect(source != nil)
        #expect(source?.label == "Existing")
    }

    @Test func deleteSource() throws {
        let sourcePath = (tempDir as NSString).appendingPathComponent("del-source")
        try FileManager.default.createDirectory(atPath: sourcePath, withIntermediateDirectories: true)
        try "".write(toFile: (sourcePath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let source = try service.install(from: sourcePath, sourceName: "to-delete", sourceLabel: "Delete Me")

        try service.deleteSource(source.id)

        let sources = try db.dbQueue.read { db in try Source.fetchAll(db) }
        #expect(sources.count == 0)
        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        #expect(skills.count == 0)
    }

    private func runGit(_ arguments: [String], in directory: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["git"] + arguments
        task.currentDirectoryURL = URL(fileURLWithPath: directory)
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        #expect(task.terminationStatus == 0)
    }

    private func createGitRepo(named name: String, files: [String: String]) throws -> String {
        let repoPath = (tempDir as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)

        for (relativePath, contents) in files {
            let fullPath = (repoPath as NSString).appendingPathComponent(relativePath)
            let parentDir = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            try contents.write(toFile: fullPath, atomically: true, encoding: .utf8)
        }

        try runGit(["init"], in: repoPath)
        try runGit(["add", "."], in: repoPath)
        try runGit([
            "-c", "user.name=SkillHub Tests",
            "-c", "user.email=tests@example.invalid",
            "commit", "-m", "Add fixture"
        ], in: repoPath)

        return repoPath
    }
}
