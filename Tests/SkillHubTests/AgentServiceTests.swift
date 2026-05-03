import XCTest
@testable import SkillHub

final class AgentServiceTests: XCTestCase {
    var db: DatabaseService!

    override func setUp() {
        super.setUp()
        db = try! DatabaseService(inMemory: true)
    }

    func testAgentDefinitions() {
        let definitions = AgentService.knownAgents
        XCTAssertFalse(definitions.isEmpty, "Should have known agents defined")
        for def in definitions {
            XCTAssertFalse(def.name.isEmpty, "Agent name must not be empty")
        }
    }

    func testDetectAgentsByConfigPath() {
        let tmpHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-home-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(atPath: tmpHome.path, withIntermediateDirectories: true)
        let claudeDir = tmpHome.appendingPathComponent(".claude")
        try! FileManager.default.createDirectory(atPath: claudeDir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpHome.path) }

        let service = AgentService(database: db, homeOverride: tmpHome.path)
        let agents = service.detect()

        let hasClaude = agents.contains { $0.name == "Claude Code" }
        XCTAssertTrue(hasClaude, "Should detect Claude Code by ~/.claude/ config directory")
    }

    func testDetectAgentsEmptyHome() {
        let tmpHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-empty-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(atPath: tmpHome.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpHome.path) }

        let service = AgentService(database: db, homeOverride: tmpHome.path)
        let agents = service.detect()
        XCTAssertEqual(agents.count, AgentService.knownAgents.count, "All known agents should be persisted regardless of presence")
        let installedCount = agents.filter { $0.installed }.count
        XCTAssertEqual(installedCount, 0, "No agents should be marked as installed in empty home")
    }

    func testAgentPersistence() throws {
        let tmpHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-persist-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(atPath: tmpHome.path, withIntermediateDirectories: true)
        let claudeDir = tmpHome.appendingPathComponent(".claude")
        try! FileManager.default.createDirectory(atPath: claudeDir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpHome.path) }

        let service = AgentService(database: db, homeOverride: tmpHome.path)
        let agents = service.detect()
        XCTAssertFalse(agents.isEmpty)

        let stored = try db.dbQueue.read { db in try Agent.fetchAll(db) }
        XCTAssertEqual(stored.count, agents.count)
    }

    func testRescanClearsOldAgents() throws {
        let tmpHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rescan-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(atPath: tmpHome.path, withIntermediateDirectories: true)
        let claudeDir = tmpHome.appendingPathComponent(".claude")
        try! FileManager.default.createDirectory(atPath: claudeDir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpHome.path) }

        let service = AgentService(database: db, homeOverride: tmpHome.path)
        _ = service.detect()
        let totalAgents = try db.dbQueue.read { db in try Agent.fetchCount(db) }
        XCTAssertEqual(totalAgents, AgentService.knownAgents.count)

        try FileManager.default.removeItem(atPath: claudeDir.path)
        _ = service.detect()
        let afterRescan = try db.dbQueue.read { db in try Agent.fetchAll(db) }
        XCTAssertEqual(afterRescan.count, AgentService.knownAgents.count)
        let installedClaude = afterRescan.first { $0.name == "Claude Code" }
        XCTAssertEqual(installedClaude?.installed, false, "Claude Code should no longer be installed after config dir removed")
    }
}
