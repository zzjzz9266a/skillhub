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

        try service.deleteSource(source.id!)

        let sources = try db.dbQueue.read { db in try Source.fetchAll(db) }
        #expect(sources.count == 0)
        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        #expect(skills.count == 0)
    }
}
