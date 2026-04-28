# SkillHub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build SkillHub, a macOS native app (SwiftUI + AppKit) for centralized AI Coding Agent skill management with source/group/skill toggle granularity.

**Architecture:** Three core services (SkillService, AgentService, SyncService) backed by GRDB/SQLite + YAML config, exposed through ObservableObject view models to SwiftUI views. Menu bar extra via NSApplicationDelegateAdaptor for quick access.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit, GRDB (SQLite), Yams, FSEvents, NSWorkspace, FileManager, Swift Package Manager.

---

## File Structure

```
Sources/SkillHub/
├── SkillHubApp.swift           # @main entry, NSApplicationDelegateAdaptor
├── AppDelegate.swift           # Menu bar + window lifecycle
├── Models/
│   ├── Source.swift            # GRDB model: sources table
│   ├── Skill.swift             # GRDB model: skills table
│   ├── Agent.swift             # GRDB model: agents table
│   └── AgentSkill.swift        # GRDB model: agent_skill join table
├── Services/
│   ├── DatabaseService.swift   # GRDB setup, migrations, queries
│   ├── SkillService.swift      # Install, parse, group management
│   ├── AgentService.swift      # Detect installed agents
│   └── SyncService.swift       # Symlink create/delete, batch toggles
├── ViewModels/
│   └── AppViewModel.swift      # @ObservableObject bridging all services to UI
├── Views/
│   ├── ContentView.swift       # Main window layout (sidebar + matrix + install bar)
│   ├── SidebarView.swift       # Source list + Agent list
│   ├── SkillMatrixView.swift   # Tree rows (source→group→skill) × Agent columns
│   ├── InstallBarView.swift    # Bottom bar: URL input + install button + status
│   └── MenuBarView.swift       # NSMenu for status bar item content
└── Utilities/
    └── SourceParser.swift      # Git/npm/local detection via pure rules

Tests/SkillHubTests/
├── DatabaseServiceTests.swift
├── SourceParserTests.swift
├── SkillServiceTests.swift
├── AgentServiceTests.swift
└── SyncServiceTests.swift
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/SkillHub/SkillHubApp.swift`
- Create: `Sources/SkillHub/AppDelegate.swift`
- Create: all other files as empty stubs (listed below)

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkillHub",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "SkillHub",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .testTarget(
            name: "SkillHubTests",
            dependencies: ["SkillHub"]
        ),
    ]
)
```

- [ ] **Step 2: Create Sources/SkillHub/SkillHubApp.swift** (minimal stub)

```swift
import SwiftUI

@main
struct SkillHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("SkillHub")
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
```

- [ ] **Step 3: Create Sources/SkillHub/AppDelegate.swift** (stub)

```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
```

- [ ] **Step 4: Create empty stub files** (so the target compiles)

Create the following files with minimal content:

`Sources/SkillHub/Models/Source.swift`:
```swift
import Foundation
struct Source: Identifiable { let id: Int64; let name: String }
```

`Sources/SkillHub/Models/Skill.swift`:
```swift
import Foundation
struct Skill: Identifiable { let id: Int64; let name: String }
```

`Sources/SkillHub/Models/Agent.swift`:
```swift
import Foundation
struct Agent: Identifiable { let id: Int64; let name: String }
```

`Sources/SkillHub/Models/AgentSkill.swift`:
```swift
import Foundation
struct AgentSkill { let agentId: Int64; let skillId: Int64; let enabled: Bool }
```

`Sources/SkillHub/Services/DatabaseService.swift`:
```swift
import Foundation
final class DatabaseService {}
```

`Sources/SkillHub/Services/SkillService.swift`:
```swift
import Foundation
final class SkillService {}
```

`Sources/SkillHub/Services/AgentService.swift`:
```swift
import Foundation
final class AgentService {}
```

`Sources/SkillHub/Services/SyncService.swift`:
```swift
import Foundation
final class SyncService {}
```

`Sources/SkillHub/ViewModels/AppViewModel.swift`:
```swift
import Foundation
final class AppViewModel: ObservableObject {}
```

`Sources/SkillHub/Views/ContentView.swift`:
```swift
import SwiftUI
struct ContentView: View { var body: some View { EmptyView() } }
```

`Sources/SkillHub/Views/SidebarView.swift`:
```swift
import SwiftUI
struct SidebarView: View { var body: some View { EmptyView() } }
```

`Sources/SkillHub/Views/SkillMatrixView.swift`:
```swift
import SwiftUI
struct SkillMatrixView: View { var body: some View { EmptyView() } }
```

`Sources/SkillHub/Views/InstallBarView.swift`:
```swift
import SwiftUI
struct InstallBarView: View { var body: some View { EmptyView() } }
```

`Sources/SkillHub/Views/MenuBarView.swift`:
```swift
import AppKit
final class MenuBarView {}
```

`Sources/SkillHub/Utilities/SourceParser.swift`:
```swift
import Foundation
enum SourceType { case git, npm, local }
struct SourceParser { static func parse(_ input: String) -> SourceType? { nil } }
```

- [ ] **Step 5: Build to verify scaffolding**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git init
git add Package.swift Sources/ .gitignore
git commit -m "chore: scaffold SkillHub Swift project with GRDB + Yams dependencies"
```

---

### Task 2: Database Models & Service

**Files:**
- Create: `Tests/SkillHubTests/DatabaseServiceTests.swift`
- Modify: `Sources/SkillHub/Models/Source.swift`
- Modify: `Sources/SkillHub/Models/Skill.swift`
- Modify: `Sources/SkillHub/Models/Agent.swift`
- Modify: `Sources/SkillHub/Models/AgentSkill.swift`
- Modify: `Sources/SkillHub/Services/DatabaseService.swift`

- [ ] **Step 1: Write the failing test**

In `Tests/SkillHubTests/DatabaseServiceTests.swift`:

```swift
import XCTest
import GRDB
@testable import SkillHub

final class DatabaseServiceTests: XCTestCase {
    var db: DatabaseService!

    override func setUp() {
        super.setUp()
        // In-memory database for tests
        db = try! DatabaseService(inMemory: true)
    }

    func testInsertAndFetchSource() throws {
        var source = Source(id: nil, name: "superpowers", label: "Superpowers", origin: "https://github.com/obra/superpowers.git", installedAt: Date())
        try db.dbQueue.write { db in
            try source.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Source.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "superpowers")
        XCTAssertEqual(fetched.first?.label, "Superpowers")
    }

    func testInsertAndFetchSkill() throws {
        let source = Source(id: nil, name: "test", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in
            try source.insert(db)
        }
        var skill = Skill(id: nil, name: "brainstorming", sourceId: source.id!, installPath: "/tmp/test", groups: ["gsd"], version: "1.0", installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in
            try skill.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Skill.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "brainstorming")
        XCTAssertEqual(fetched.first?.groups, ["gsd"])
    }

    func testInsertAndFetchAgent() throws {
        var agent = Agent(id: nil, name: "Claude Code", configPath: "~/.claude/", detectedAt: Date(), hotReloadSupported: true)
        try db.dbQueue.write { db in
            try agent.insert(db)
        }
        let fetched = try db.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Claude Code")
        XCTAssertTrue(fetched.first?.hotReloadSupported ?? false)
    }

    func testAgentSkillToggle() throws {
        let source = Source(id: nil, name: "test", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in try source.insert(db) }
        var skill = Skill(id: nil, name: "test-skill", sourceId: source.id!, installPath: "/tmp/test", groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill.insert(db) }
        var agent = Agent(id: nil, name: "TestAgent", configPath: nil, detectedAt: Date(), hotReloadSupported: true)
        try db.dbQueue.write { db in try agent.insert(db) }

        // Insert enabled state
        var agentSkill = AgentSkill(agentId: agent.id!, skillId: skill.id!, enabled: true)
        try db.dbQueue.write { db in try agentSkill.save(db) }

        // Verify
        let states = try db.dbQueue.read { db in
            try AgentSkill.fetchAll(db)
        }
        XCTAssertEqual(states.count, 1)
        XCTAssertTrue(states.first?.enabled ?? false)

        // Toggle off
        agentSkill.enabled = false
        try db.dbQueue.write { db in try agentSkill.save(db) }

        let updated = try db.dbQueue.read { db in
            try AgentSkill.fetchAll(db)
        }
        XCTAssertFalse(updated.first?.enabled ?? true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DatabaseServiceTests`
Expected: FAIL — models not yet matching GRDB requirements.

- [ ] **Step 3: Implement GRDB models**

`Sources/SkillHub/Models/Source.swift`:
```swift
import GRDB
import Foundation

struct Source: Codable {
    var id: Int64?
    var name: String
    var label: String
    var origin: String
    var installedAt: Date
}

extension Source: FetchableRecord, PersistableRecord {
    static let databaseTableName = "sources"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let label = Column(CodingKeys.label)
        static let origin = Column(CodingKeys.origin)
        static let installedAt = Column(CodingKeys.installedAt)
    }
}
```

`Sources/SkillHub/Models/Skill.swift`:
```swift
import GRDB
import Foundation

struct Skill: Codable {
    var id: Int64?
    var name: String
    var sourceId: Int64
    var installPath: String
    var groups: [String]
    var version: String?
    var installedAt: Date
    var updatedAt: Date
}

extension Skill: FetchableRecord, PersistableRecord {
    static let databaseTableName = "skills"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let sourceId = Column(CodingKeys.sourceId)
        static let installPath = Column(CodingKeys.installPath)
        static let groups = Column(CodingKeys.groups)
        static let version = Column(CodingKeys.version)
        static let installedAt = Column(CodingKeys.installedAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
```

`Sources/SkillHub/Models/Agent.swift`:
```swift
import GRDB
import Foundation

struct Agent: Codable {
    var id: Int64?
    var name: String
    var configPath: String?
    var detectedAt: Date
    var hotReloadSupported: Bool
}

extension Agent: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agents"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let configPath = Column(CodingKeys.configPath)
        static let detectedAt = Column(CodingKeys.detectedAt)
        static let hotReloadSupported = Column(CodingKeys.hotReloadSupported)
    }
}
```

`Sources/SkillHub/Models/AgentSkill.swift`:
```swift
import GRDB
import Foundation

struct AgentSkill: Codable {
    var agentId: Int64
    var skillId: Int64
    var enabled: Bool
}

extension AgentSkill: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_skill"

    enum Columns {
        static let agentId = Column(CodingKeys.agentId)
        static let skillId = Column(CodingKeys.skillId)
        static let enabled = Column(CodingKeys.enabled)
    }
}
```

`Sources/SkillHub/Services/DatabaseService.swift`:
```swift
import GRDB
import Foundation

final class DatabaseService {
    let dbQueue: DatabaseQueue

    init(path: String? = nil, inMemory: Bool = false) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else if let path = path {
            dbQueue = try DatabaseQueue(path: path)
        } else {
            let hubDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".skillhub")
            try FileManager.default.createDirectory(at: hubDir, withIntermediateDirectories: true)
            let dbPath = hubDir.appendingPathComponent("state.db").path
            dbQueue = try DatabaseQueue(path: dbPath)
        }
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "sources") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
                t.column("label", .text).notNull()
                t.column("origin", .text).notNull()
                t.column("installedAt", .datetime).notNull()
                    .defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "skills") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sourceId", .integer).notNull()
                    .references("sources", onDelete: .cascade)
                t.column("installPath", .text).notNull()
                t.column("groups", .text).notNull().defaults(to: "[]")
                t.column("version", .text)
                t.column("installedAt", .datetime).notNull()
                    .defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull()
                    .defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "agents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
                t.column("configPath", .text)
                t.column("detectedAt", .datetime).notNull()
                    .defaults(sql: "CURRENT_TIMESTAMP")
                t.column("hotReloadSupported", .boolean).notNull()
                    .defaults(to: false)
            }
            try db.create(table: "agent_skill") { t in
                t.column("agentId", .integer).notNull()
                    .references("agents", onDelete: .cascade)
                t.column("skillId", .integer).notNull()
                    .references("skills", onDelete: .cascade)
                t.column("enabled", .boolean).notNull().defaults(to: false)
                t.primaryKey(["agentId", "skillId"])
            }
        }
        try migrator.migrate(dbQueue)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DatabaseServiceTests`
Expected: PASS — all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SkillHub/Models/ Sources/SkillHub/Services/DatabaseService.swift Tests/
git commit -m "feat: add GRDB models (Source, Skill, Agent, AgentSkill) and DatabaseService with migrations"
```

---

### Task 3: SourceParser Utility

**Files:**
- Create: `Tests/SkillHubTests/SourceParserTests.swift`
- Modify: `Sources/SkillHub/Utilities/SourceParser.swift`

- [ ] **Step 1: Write the failing test**

In `Tests/SkillHubTests/SourceParserTests.swift`:

```swift
import XCTest
@testable import SkillHub

final class SourceParserTests: XCTestCase {
    func testGitHTTPS() {
        let result = SourceParser.parse("https://github.com/obra/superpowers.git")
        guard case .git = result else {
            XCTFail("Expected git, got \(String(describing: result))")
            return
        }
    }

    func testGitSSH() {
        let result = SourceParser.parse("git@github.com:user/repo.git")
        guard case .git = result else {
            XCTFail("Expected git, got \(String(describing: result))")
            return
        }
    }

    func testNpmScoped() {
        let result = SourceParser.parse("@scope/package-name")
        guard case .npm(let name) = result else {
            XCTFail("Expected npm, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(name, "@scope/package-name")
    }

    func testLocalDirectory() {
        let tmpDir = FileManager.default.temporaryDirectory.path
        let result = SourceParser.parse(tmpDir)
        guard case .local = result else {
            XCTFail("Expected local, got \(String(describing: result))")
            return
        }
    }

    func testInvalidInput() {
        let result = SourceParser.parse("not-a-valid-source")
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SourceParserTests`
Expected: FAIL — `parse` returns nil for everything.

- [ ] **Step 3: Implement SourceParser**

`Sources/SkillHub/Utilities/SourceParser.swift`:
```swift
import Foundation

enum SourceType: Equatable {
    case git(url: String)
    case npm(name: String)
    case local(path: String)
}

enum SourceParser {
    static func parse(_ input: String) -> SourceType? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Git: https://, git@, ssh://, or .git suffix
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("git@") || trimmed.hasPrefix("ssh://") {
            return .git(url: trimmed)
        }
        if trimmed.hasSuffix(".git") {
            return .git(url: trimmed)
        }

        // npm: @scope/name or package-name (no slashes, no dots as path)
        if trimmed.hasPrefix("@") && trimmed.contains("/") {
            return .npm(name: trimmed)
        }

        // local: must be an existing directory
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory), isDirectory.boolValue {
            return .local(path: trimmed)
        }

        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SourceParserTests`
Expected: PASS — all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SkillHub/Utilities/SourceParser.swift Tests/SkillHubTests/SourceParserTests.swift
git commit -m "feat: add SourceParser for git/npm/local source type detection"
```

---

### Task 4: SkillService

**Files:**
- Create: `Tests/SkillHubTests/SkillServiceTests.swift`
- Modify: `Sources/SkillHub/Services/SkillService.swift`

- [ ] **Step 1: Write the failing test**

In `Tests/SkillHubTests/SkillServiceTests.swift`:

```swift
import XCTest
@testable import SkillHub

final class SkillServiceTests: XCTestCase {
    var db: DatabaseService!
    var service: SkillService!
    var tempDir: String!

    override func setUp() {
        super.setUp()
        db = try! DatabaseService(inMemory: true)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try! FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        service = SkillService(database: db, skillsStorePath: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    func testInstallLocalSkill() throws {
        // Create a mock skill directory with SKILL.md
        let skillDir = (tempDir as NSString).appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
        let skillMD = (skillDir as NSString).appendingPathComponent("SKILL.md")
        try "# Test Skill\nA test skill for unit testing".write(toFile: skillMD, atomically: true, encoding: .utf8)

        // Install
        let source = try service.install(from: skillDir, sourceName: "test-source", sourceLabel: "Test Source")
        XCTAssertEqual(source.name, "test-source")

        // Verify source was stored
        let sources = try db.dbQueue.read { db in try Source.fetchAll(db) }
        XCTAssertEqual(sources.count, 1)

        // Verify skill was stored
        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "test-skill")

        // Verify skill files were copied to store
        let installedPath = skills.first!.installPath
        XCTAssertTrue(FileManager.default.fileExists(atPath: installedPath))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: (installedPath as NSString).appendingPathComponent("SKILL.md")))
    }

    func testInstallMultipleSkillsInDirectory() throws {
        // Create a directory with two skills
        let sourceDir = (tempDir as NSString).appendingPathComponent("multi-skill-source")
        try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)

        let skillADir = (sourceDir as NSString).appendingPathComponent("skill-a")
        try FileManager.default.createDirectory(atPath: skillADir, withIntermediateDirectories: true)
        try "# Skill A".write(toFile: (skillADir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let skillBDir = (sourceDir as NSString).appendingPathComponent("skill-b")
        try FileManager.default.createDirectory(atPath: skillBDir, withIntermediateDirectories: true)
        try "# Skill B".write(toFile: (skillBDir as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Create a non-skill directory (no SKILL.md)
        let nonSkillDir = (sourceDir as NSString).appendingPathComponent("not-a-skill")
        try FileManager.default.createDirectory(atPath: nonSkillDir, withIntermediateDirectories: true)

        _ = try service.install(from: sourceDir, sourceName: "multi", sourceLabel: "Multi Skill Source")

        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        XCTAssertEqual(skills.count, 2, "Only directories with SKILL.md should be counted as skills")
        let names = skills.map { $0.name }.sorted()
        XCTAssertEqual(names, ["skill-a", "skill-b"])
    }

    func testGetExistingSource() throws {
        let sourcePath = (tempDir as NSString).appendingPathComponent("exist-source")
        try FileManager.default.createDirectory(atPath: sourcePath, withIntermediateDirectories: true)
        try "".write(toFile: (sourcePath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        _ = try service.install(from: sourcePath, sourceName: "existing", sourceLabel: "Existing")

        let source = try service.getSource(by: "existing")
        XCTAssertNotNil(source)
        XCTAssertEqual(source?.label, "Existing")
    }

    func testDeleteSource() throws {
        let sourcePath = (tempDir as NSString).appendingPathComponent("del-source")
        try FileManager.default.createDirectory(atPath: sourcePath, withIntermediateDirectories: true)
        try "".write(toFile: (sourcePath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let source = try service.install(from: sourcePath, sourceName: "to-delete", sourceLabel: "Delete Me")

        try service.deleteSource(source.id!)

        let sources = try db.dbQueue.read { db in try Source.fetchAll(db) }
        XCTAssertEqual(sources.count, 0)
        let skills = try db.dbQueue.read { db in try Skill.fetchAll(db) }
        XCTAssertEqual(skills.count, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SkillServiceTests`
Expected: FAIL — SkillService not implemented.

- [ ] **Step 3: Implement SkillService**

`Sources/SkillHub/Services/SkillService.swift`:
```swift
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

        // Create source in DB
        var source = Source(id: nil, name: sourceName, label: sourceLabel, origin: expanded, installedAt: Date())
        try database.dbQueue.write { db in
            // Upsert: delete existing if exists
            if let existing = try Source.filter(Source.Columns.name == sourceName).fetchOne(db) {
                source.id = existing.id
                try source.update(db)
            } else {
                try source.insert(db)
            }
            // Make sure we have the id
            if source.id == nil {
                source = try Source.filter(Source.Columns.name == sourceName).fetchOne(db)!
            }
        }

        // Scan for skills (directories containing SKILL.md or skill.md)
        let targetDir = (skillsStorePath as NSString)
            .appendingPathComponent(sourceName)
        try? FileManager.default.removeItem(atPath: targetDir)
        try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        let discoveredSkills = findSkills(at: expanded)

        for skill in discoveredSkills {
            let destPath = (targetDir as NSString).appendingPathComponent(skill.name)
            try FileManager.default.copyItem(atPath: skill.path, toPath: destPath)

            var record = Skill(
                id: nil,
                name: skill.name,
                sourceId: source.id!,
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
            // Single skill: the path itself contains SKILL.md
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
        // Default: use the parent directory name as group
        // Override via SKILL.md frontmatter parsing (future enhancement)
        let skillMDPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOfFile: skillMDPath, encoding: .utf8) else {
            return []
        }
        // Parse YAML frontmatter for group metadata
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SkillServiceTests`
Expected: PASS — all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SkillHub/Services/SkillService.swift Tests/SkillHubTests/SkillServiceTests.swift
git commit -m "feat: add SkillService with install, get, delete for skill discovery and storage"
```

---

### Task 5: AgentService

**Files:**
- Create: `Tests/SkillHubTests/AgentServiceTests.swift`
- Modify: `Sources/SkillHub/Services/AgentService.swift`

- [ ] **Step 1: Write the failing test**

In `Tests/SkillHubTests/AgentServiceTests.swift`:

```swift
import XCTest
@testable import SkillHub

final class AgentServiceTests: XCTestCase {
    var db: DatabaseService!

    override func setUp() {
        super.setUp()
        db = try! DatabaseService(inMemory: true)
    }

    func testAgentDefinitions() {
        // Verify all known agents have valid definitions
        let definitions = AgentService.knownAgents
        XCTAssertFalse(definitions.isEmpty, "Should have known agents defined")
        for def in definitions {
            XCTAssertFalse(def.name.isEmpty, "Agent name must not be empty")
        }
    }

    func testDetectAgentsByConfigPath() {
        // Create a fake home with `.claude/` directory
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
        XCTAssertEqual(agents.count, 0, "Empty home should detect 0 agents")
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

        // Verify persisted in DB
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
        XCTAssertEqual(try db.dbQueue.read { db in try Agent.fetchCount(db) }, 1)

        // Remove the directory and rescan
        try FileManager.default.removeItem(atPath: claudeDir.path)
        _ = service.detect()
        XCTAssertEqual(try db.dbQueue.read { db in try Agent.fetchCount(db) }, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AgentServiceTests`
Expected: FAIL — AgentService not implemented.

- [ ] **Step 3: Implement AgentService**

`Sources/SkillHub/Services/AgentService.swift`:
```swift
import GRDB
import Foundation

struct AgentDefinition {
    let name: String
    let configPaths: [String]  // relative to home
    let hotReloadSupported: Bool
}

final class AgentService {
    let database: DatabaseService
    let homePath: String

    static let knownAgents: [AgentDefinition] = [
        AgentDefinition(name: "Claude Code", configPaths: [".claude"], hotReloadSupported: false),
        AgentDefinition(name: "OpenCode", configPaths: [".opencode"], hotReloadSupported: false),
        AgentDefinition(name: "Gemini CLI", configPaths: [".gemini"], hotReloadSupported: false),
        AgentDefinition(name: "Codex", configPaths: [".codex"], hotReloadSupported: false),
        AgentDefinition(name: "Copilot CLI", configPaths: [".config/github-copilot"], hotReloadSupported: false),
    ]

    init(database: DatabaseService, homeOverride: String? = nil) {
        self.database = database
        self.homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    @discardableResult
    func detect() -> [Agent] {
        let found = Self.knownAgents.compactMap { def -> Agent? in
            let exists = def.configPaths.contains { configPath in
                let fullPath = (homePath as NSString).appendingPathComponent(configPath)
                return FileManager.default.fileExists(atPath: fullPath)
            }
            guard exists else { return nil }
            return Agent(
                id: nil,
                name: def.name,
                configPath: def.configPaths.first.map { (homePath as NSString).appendingPathComponent($0) },
                detectedAt: Date(),
                hotReloadSupported: def.hotReloadSupported
            )
        }

        // Replace stored agents
        try? database.dbQueue.write { db in
            try Agent.deleteAll(db)
            for var agent in found {
                try agent.insert(db)
            }
        }

        return found
    }

    func listAgents() throws -> [Agent] {
        return try database.dbQueue.read { db in
            try Agent.fetchAll(db)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AgentServiceTests`
Expected: PASS — all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SkillHub/Services/AgentService.swift Tests/SkillHubTests/AgentServiceTests.swift
git commit -m "feat: add AgentService to detect installed AI coding agents by config directory"
```

---

### Task 6: SyncService

**Files:**
- Create: `Tests/SkillHubTests/SyncServiceTests.swift`
- Modify: `Sources/SkillHub/Services/SyncService.swift`

- [ ] **Step 1: Write the failing test**

In `Tests/SkillHubTests/SyncServiceTests.swift`:

```swift
import XCTest
@testable import SkillHub

final class SyncServiceTests: XCTestCase {
    var db: DatabaseService!
    var sync: SyncService!
    var tempHome: String!
    var skillsRoot: String!

    override func setUp() {
        super.setUp()
        db = try! DatabaseService(inMemory: true)
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("synctest-\(UUID().uuidString)").path
        try! FileManager.default.createDirectory(atPath: tempHome, withIntermediateDirectories: true)
        skillsRoot = (tempHome as NSString).appendingPathComponent(".skillhub/skills")
        try! FileManager.default.createDirectory(atPath: skillsRoot, withIntermediateDirectories: true)
        sync = SyncService(database: db, homeOverride: tempHome)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempHome)
        super.tearDown()
    }

    private func createFixture() throws -> (sourceId: Int64, skillId: Int64, agentId: Int64, agentSkillDir: String) {
        var source = Source(id: nil, name: "test-src", label: "Test", origin: "local", installedAt: Date())
        try db.dbQueue.write { db in try source.insert(db) }
        source = try db.dbQueue.read { db in try Source.fetchOne(db)! }

        let skillPath = (skillsRoot as NSString).appendingPathComponent("test-src/my-skill")
        try FileManager.default.createDirectory(atPath: skillPath, withIntermediateDirectories: true)
        try "test content".write(toFile: (skillPath as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        var skill = Skill(id: nil, name: "my-skill", sourceId: source.id!, installPath: skillPath, groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill.insert(db) }
        skill = try db.dbQueue.read { db in try Skill.fetchOne(db)! }

        var agent = Agent(id: nil, name: "TestAgent", configPath: nil, detectedAt: Date(), hotReloadSupported: true)
        try db.dbQueue.write { db in try agent.insert(db) }
        agent = try db.dbQueue.read { db in try Agent.fetchOne(db)! }

        let agentSkillDir = (tempHome as NSString).appendingPathComponent(".claude/skills")
        try FileManager.default.createDirectory(atPath: agentSkillDir, withIntermediateDirectories: true)

        return (source.id!, skill.id!, agent.id!, agentSkillDir)
    }

    func testEnableSkillCreatesSymlink() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()

        // Enable skill -> should create symlink
        try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        // Verify DB state
        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        XCTAssertNotNil(state)
        XCTAssertTrue(state!.enabled)

        // Verify symlink exists
        let linkPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: linkPath, isDirectory: &isDir))

        // Verify it's a symlink
        let attrs = try FileManager.default.attributesOfItem(atPath: linkPath)
        XCTAssertEqual(attrs[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testDisableSkillRemovesSymlink() throws {
        let (_, skillId, agentId, agentSkillDir) = try createFixture()

        // Enable first
        try sync.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        // Disable
        try sync.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: agentSkillDir)

        // Verify DB state
        let state = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId && AgentSkill.Columns.skillId == skillId).fetchOne(db)
        }
        if let state = state {
            XCTAssertFalse(state.enabled)
        }

        // Verify symlink is removed
        let linkPath = (agentSkillDir as NSString).appendingPathComponent("my-skill")
        XCTAssertFalse(FileManager.default.fileExists(atPath: linkPath))
    }

    func testBatchEnableSource() throws {
        let (sourceId, _, agentId, agentSkillDir) = try createFixture()

        // Add a second skill to the same source
        let skill2Path = (skillsRoot as NSString).appendingPathComponent("test-src/skill-2")
        try FileManager.default.createDirectory(atPath: skill2Path, withIntermediateDirectories: true)
        try "content".write(toFile: (skill2Path as NSString).appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        var skill2 = Skill(id: nil, name: "skill-2", sourceId: sourceId, installPath: skill2Path, groups: [], version: nil, installedAt: Date(), updatedAt: Date())
        try db.dbQueue.write { db in try skill2.insert(db) }

        // Batch enable all skills from the source
        try sync.enableSource(sourceId: sourceId, agentId: agentId, agentSkillsDir: agentSkillDir)

        let states = try db.dbQueue.read { db in
            try AgentSkill.filter(AgentSkill.Columns.agentId == agentId).fetchAll(db)
        }
        XCTAssertEqual(states.count, 2)
        XCTAssertTrue(states.allSatisfy { $0.enabled })

        // Verify both symlinks exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: (agentSkillDir as NSString).appendingPathComponent("my-skill")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (agentSkillDir as NSString).appendingPathComponent("skill-2")))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SyncServiceTests`
Expected: FAIL — SyncService not implemented.

- [ ] **Step 3: Implement SyncService**

`Sources/SkillHub/Services/SyncService.swift`:
```swift
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
        // Get the skill
        guard let skill = try database.dbQueue.read({ db in
            try Skill.fetchOne(db, id: skillId)
        }) else {
            throw SyncError.skillNotFound
        }

        // Create symlink
        let linkPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        if FileManager.default.fileExists(atPath: linkPath) {
            try FileManager.default.removeItem(atPath: linkPath)
        }
        try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: skill.installPath)

        // Update DB
        var agentSkill = AgentSkill(agentId: agentId, skillId: skillId, enabled: true)
        try database.dbQueue.write { db in
            try agentSkill.save(db)
        }
    }

    func disableSkill(skillId: Int64, agentId: Int64, agentSkillsDir: String) throws {
        guard let skill = try database.dbQueue.read({ db in
            try Skill.fetchOne(db, id: skillId)
        }) else {
            throw SyncError.skillNotFound
        }

        // Remove symlink
        let linkPath = (agentSkillsDir as NSString).appendingPathComponent(skill.name)
        if FileManager.default.fileExists(atPath: linkPath) {
            try FileManager.default.removeItem(atPath: linkPath)
        }

        // Update DB
        var agentSkill = AgentSkill(agentId: agentId, skillId: skillId, enabled: false)
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
                try enableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                // Log but continue
                print("Failed to enable \(skill.name): \(error)")
            }
        }
    }

    func enableGroup(sourceId: Int64, groupName: String, agentId: Int64, agentSkillsDir: String) throws {
        let skills = try database.dbQueue.read { db in
            try Skill.filter(Skill.Columns.sourceId == sourceId).fetchAll(db)
        }
        let groupedSkills = skills.filter { $0.groups.contains(groupName) }
        for skill in groupedSkills {
            do {
                try enableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: agentSkillsDir)
            } catch {
                print("Failed to enable \(skill.name): \(error)")
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

enum SyncError: LocalizedError {
    case skillNotFound

    var errorDescription: String? {
        switch self {
        case .skillNotFound: return "Skill not found in database"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SyncServiceTests`
Expected: PASS — all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SkillHub/Services/SyncService.swift Tests/SkillHubTests/SyncServiceTests.swift
git commit -m "feat: add SyncService for skill symlink management with skill/source/group-level toggle"
```

---

### Task 7: AppViewModel

**Files:**
- Modify: `Sources/SkillHub/ViewModels/AppViewModel.swift`

- [ ] **Step 1: Implement AppViewModel**

`Sources/SkillHub/ViewModels/AppViewModel.swift`:
```swift
import Foundation
import Combine

final class AppViewModel: ObservableObject {
    // MARK: - Published state
    @Published var sources: [Source] = []
    @Published var skills: [Skill] = []
    @Published var agents: [Agent] = []
    @Published var agentSkillStates: [Int64: [Int64: Bool]] = [:]  // agentId -> [skillId: enabled]
    @Published var selectedSourceId: Int64?
    @Published var installInput: String = ""
    @Published var statusText: String = ""

    // MARK: - Services
    let database: DatabaseService
    let skillService: SkillService
    let agentService: AgentService
    let syncService: SyncService

    init(homeOverride: String? = nil) {
        let homePath = homeOverride ?? FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = (homePath as NSString).appendingPathComponent(".skillhub/state.db")

        self.database = (try? DatabaseService(path: dbPath)) ?? (try! DatabaseService(inMemory: true))
        self.skillService = SkillService(database: database)
        self.agentService = AgentService(database: database, homeOverride: homePath)
        self.syncService = SyncService(database: database, homeOverride: homePath)
    }

    // MARK: - Lifecycle

    func refresh() {
        refreshSources()
        refreshSkills()
        let found = agentService.detect()
        self.agents = found
        refreshAllAgentStates()
        updateStatus()
    }

    private func refreshSources() {
        self.sources = (try? database.dbQueue.read { db in try Source.fetchAll(db) }) ?? []
    }

    private func refreshSkills() {
        self.skills = (try? database.dbQueue.read { db in try Skill.fetchAll(db) }) ?? []
    }

    private func refreshAllAgentStates() {
        for agent in agents {
            let states = (try? syncService.getAgentSkillStates(agentId: agent.id!)) ?? [:]
            agentSkillStates[agent.id!] = states
        }
    }

    private func updateStatus() {
        let agentCount = agents.count
        let skillCount = skills.count
        statusText = "\(agentCount) agents detected | \(skillCount) skills installed"
    }

    // MARK: - Toggle operations

    func toggleSkill(skillId: Int64, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        try? FileManager.default.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)

        if enabled {
            try? syncService.enableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
        } else {
            try? syncService.disableSkill(skillId: skillId, agentId: agentId, agentSkillsDir: skillsDir)
        }

        agentSkillStates[agentId, default: [:]][skillId] = enabled
    }

    func toggleSource(sourceId: Int64, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        let sourceSkills = skills.filter { $0.sourceId == sourceId }
        for skill in sourceSkills {
            if enabled {
                try? syncService.enableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: skillsDir)
            } else {
                try? syncService.disableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: skillsDir)
            }
        }

        for skill in sourceSkills {
            agentSkillStates[agentId, default: [:]][skill.id!] = enabled
        }
    }

    func toggleGroup(sourceId: Int64, groupName: String, agentId: Int64, enabled: Bool) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }
        let skillsDir = agentSkillsDirectory(for: agent)

        let groupSkills = skills.filter { $0.sourceId == sourceId && $0.groups.contains(groupName) }
        for skill in groupSkills {
            if enabled {
                try? syncService.enableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: skillsDir)
            } else {
                try? syncService.disableSkill(skillId: skill.id!, agentId: agentId, agentSkillsDir: skillsDir)
            }
        }

        for skill in groupSkills {
            agentSkillStates[agentId, default: [:]][skill.id!] = enabled
        }
    }

    // MARK: - Install

    func install() {
        guard !installInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        statusText = "Installing..."
        let input = installInput.trimmingCharacters(in: .whitespaces)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let sourceName = (input as NSString).lastPathComponent
                    .replacingOccurrences(of: ".git", with: "")
                _ = try self.skillService.install(from: input, sourceName: sourceName, sourceLabel: sourceName)
                DispatchQueue.main.async {
                    self.installInput = ""
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusText = "Install failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Helpers

    private func agentSkillsDirectory(for agent: Agent) -> String {
        if let configPath = agent.configPath {
            return (configPath as NSString).appendingPathComponent("skills")
        }
        // Fallback: use agent name to derive config path
        let pathMap: [String: String] = [
            "Claude Code": ".claude",
            "OpenCode": ".opencode",
            "Gemini CLI": ".gemini",
            "Codex": ".codex",
            "Copilot CLI": ".config/github-copilot",
        ]
        let home = agentService.homePath
        let relative = pathMap[agent.name] ?? ".claude"
        return (home as NSString).appendingPathComponent("\(relative)/skills")
    }

    var filteredSkills: [Skill] {
        guard let sourceId = selectedSourceId else { return skills }
        return skills.filter { $0.sourceId == sourceId }
    }

    func skillsForSource(_ sourceId: Int64) -> [Skill] {
        return skills.filter { $0.sourceId == sourceId }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/SkillHub/ViewModels/AppViewModel.swift
git commit -m "feat: add AppViewModel bridging services to SwiftUI with toggle/install operations"
```

---

### Task 8: UI Views

**Files:**
- Modify: `Sources/SkillHub/Views/SidebarView.swift`
- Modify: `Sources/SkillHub/Views/SkillMatrixView.swift`
- Modify: `Sources/SkillHub/Views/InstallBarView.swift`
- Modify: `Sources/SkillHub/Views/ContentView.swift`
- Modify: `Sources/SkillHub/Views/MenuBarView.swift`

- [ ] **Step 1: Implement SidebarView**

`Sources/SkillHub/Views/SidebarView.swift`:
```swift
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sources section
            Text("Sources")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Button(action: { viewModel.selectedSourceId = nil }) {
                        HStack {
                            Image(systemName: "tray.full")
                            Text("All Skills")
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(6)
                        .background(viewModel.selectedSourceId == nil ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.sources) { source in
                        Button(action: { viewModel.selectedSourceId = source.id }) {
                            HStack {
                                Image(systemName: "shippingbox")
                                Text(source.label)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(6)
                            .background(viewModel.selectedSourceId == source.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()
                .padding(.vertical, 8)

            // Agents section
            Text("Agents")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(viewModel.agents) { agent in
                HStack {
                    Circle()
                        .fill(agentStatusColor(agent))
                        .frame(width: 8, height: 8)
                    Text(agent.name)
                        .lineLimit(1)
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }

            Spacer()
        }
        .frame(minWidth: 180)
    }

    private func agentStatusColor(_ agent: Agent) -> Color {
        if agent.hotReloadSupported { return .green }
        return .yellow
    }
}
```

- [ ] **Step 2: Implement SkillMatrixView**

`Sources/SkillHub/Views/SkillMatrixView.swift`:
```swift
import SwiftUI

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.agents.isEmpty {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No agents detected")
                    .foregroundColor(.secondary)
                Text("Install an AI coding agent to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(viewModel.filteredSkills) {
                TableColumn("Skill") { skill in
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        VStack(alignment: .leading) {
                            Text(skill.name)
                                .font(.body)
                            if !skill.groups.isEmpty {
                                Text(skill.groups.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                ForEach(viewModel.agents) { agent in
                    TableColumn(agent.name) { skill in
                        let enabled = viewModel.agentSkillStates[agent.id!]?[skill.id!] ?? false
                        Toggle("", isOn: Binding(
                            get: { enabled },
                            set: { newValue in
                                viewModel.toggleSkill(skillId: skill.id!, agentId: agent.id!, enabled: newValue)
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .width(80)
                }
            }
            }
        }
    }
}
```

- [ ] **Step 3: Implement InstallBarView**

`Sources/SkillHub/Views/InstallBarView.swift`:
```swift
import SwiftUI

struct InstallBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            TextField("Paste URL or local path to install skills...", text: $viewModel.installInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.install()
                }

            Button("Install") {
                viewModel.install()
            }
            .disabled(viewModel.installInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: [.command])

            Spacer()

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
```

- [ ] **Step 4: Implement ContentView (main window layout)**

`Sources/SkillHub/Views/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HSplitView {
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 180, idealWidth: 220)

            VStack(spacing: 0) {
                // Source-level toggle bar
                if let sourceId = viewModel.selectedSourceId,
                   let source = viewModel.sources.first(where: { $0.id == sourceId }),
                   !viewModel.agents.isEmpty {
                    SourceToggleBar(source: source, viewModel: viewModel)
                }

                SkillMatrixView(viewModel: viewModel)

                InstallBarView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.refresh()
        }
    }
}

private struct SourceToggleBar: View {
    let source: Source
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text(source.label)
                .font(.headline)

            ForEach(viewModel.agents) { agent in
                let allEnabled = (viewModel.skillsForSource(source.id!).allSatisfy {
                    viewModel.agentSkillStates[agent.id!]?[$0.id!] ?? false
                })
                Button(agent.name) {
                    viewModel.toggleSource(sourceId: source.id!, agentId: agent.id!, enabled: !allEnabled)
                }
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(allEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
```

- [ ] **Step 5: Implement MenuBarView**

`Sources/SkillHub/Views/MenuBarView.swift`:
```swift
import AppKit

final class MenuBarView {
    private var statusItem: NSStatusItem!
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "SkillHub"
            button.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "SkillHub")
            button.toolTip = "SkillHub - AI Agent Skill Manager"
        }

        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()

        guard let vm = viewModel else {
            statusItem.menu = menu
            return
        }

        // Source > Group hierarchy
        for source in vm.sources {
            let sourceItem = NSMenuItem(title: source.label, action: nil, keyEquivalent: "")
            sourceItem.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)
            sourceItem.isEnabled = true

            let groupSkills = Dictionary(grouping: vm.skillsForSource(source.id!)) { skill in
                skill.groups.first ?? "ungrouped"
            }

            let submenu = NSMenu()
            for (groupName, skills) in groupSkills {
                let groupItem = NSMenuItem(title: groupName, action: nil, keyEquivalent: "")
                groupItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)

                let skillMenu = NSMenu()
                for skill in skills {
                    let skillItem = NSMenuItem(title: skill.name, action: nil, keyEquivalent: "")
                    skillItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                    skillMenu.addItem(skillItem)
                }
                groupItem.submenu = skillMenu
                submenu.addItem(groupItem)
            }
            sourceItem.submenu = submenu
            menu.addItem(sourceItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Main Window", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SkillHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "SkillHub" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func refresh() {
        viewModel?.refresh()
        buildMenu()
    }
}
```

- [ ] **Step 6: Update SkillHubApp.swift to inject shared ViewModel**

`Sources/SkillHub/SkillHubApp.swift`:
```swift
import SwiftUI

@main
struct SkillHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.viewModel)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 7: Update AppDelegate.swift**

`Sources/SkillHub/AppDelegate.swift`:
```swift
import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarView: MenuBarView?
    var viewModel: AppViewModel!
    private var fileWatcherStream: FSEventStreamRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = AppViewModel()
        menuBarView = MenuBarView(viewModel: viewModel)
        viewModel.refresh()
        menuBarView?.buildMenu()

        setupFileWatcher()
    }

    private func setupFileWatcher() {
        let hubPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".skillhub").path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, _, _, _, _, _) in
                // External change detected — refresh UI
                DispatchQueue.main.async {
                    NSApp.delegate.flatMap { ($0 as? AppDelegate)?.viewModel?.refresh() }
                }
            },
            &context,
            [hubPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        fileWatcherStream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }
}
```

- [ ] **Step 8: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds with all views compiled.

- [ ] **Step 9: Commit**

```bash
git add Sources/SkillHub/Views/ Sources/SkillHub/SkillHubApp.swift Sources/SkillHub/AppDelegate.swift
git commit -m "feat: add SwiftUI main window, sidebar, skill×agent matrix, install bar, and menu bar extra"
```

---

### Task 9: Build & Integration

**Files:** None new.

- [ ] **Step 1: Run full build**

Run: `swift build`
Expected: Full build succeeds with zero errors.

- [ ] **Step 2: Run full test suite**

Run: `swift test`
Expected: All tests pass (10+ tests across DatabaseService, SourceParser, SkillService, AgentService, SyncService).

- [ ] **Step 3: Fix any compilation issues**

If any compiler errors emerge from the full build, fix them now. Common issues at this stage:
- Import statements mismatched between files
- Type inference ambiguities in SwiftUI views
- Missing `Sendable` conformance for @MainActor contexts

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: final integration fixes, full build verification"
```

---

### Task 10: Xcode Project Generation (Optional)

- [ ] **Step 1: Generate Xcode project**

Run: `swift package generate-xcodeproj`
Expected: Creates `SkillHub.xcodeproj` for development in Xcode.

- [ ] **Step 2: Verify project opens and builds in Xcode**

Open `SkillHub.xcodeproj` in Xcode. Select the `SkillHub` scheme, press Cmd+B. Verify build succeeds.

- [ ] **Step 3: Commit Xcode project**

```bash
git add SkillHub.xcodeproj/ .gitignore
git commit -m "chore: add Xcode project for IDE development"
```
