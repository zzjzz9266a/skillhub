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
        migrator.registerMigration("v2") { db in
            try db.alter(table: "agents") { t in
                t.add(column: "visible", .boolean).notNull().defaults(to: true)
                t.add(column: "installed", .boolean).notNull().defaults(to: true)
            }
        }
        migrator.registerMigration("v3") { db in
            try db.alter(table: "agents") { t in
                t.drop(column: "hotReloadSupported")
            }
        }
        migrator.registerMigration("v4") { db in
            try db.alter(table: "skills") { t in
                t.add(column: "description", .text)
            }
        }
        try migrator.migrate(dbQueue)
    }
}
