import GRDB
import Foundation

struct Skill: Codable {
    var id: Int64 = 0
    var name: String
    var sourceId: Int64
    var installPath: String
    var groups: [String]
    var version: String?
    var installedAt: Date
    var updatedAt: Date
}

extension Skill: Identifiable {}

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

    func encode(to container: inout PersistenceContainer) {
        if id != 0 {
            container[Columns.id] = id
        }
        container[Columns.name] = name
        container[Columns.sourceId] = sourceId
        container[Columns.installPath] = installPath
        let jsonData = try! JSONEncoder().encode(groups)
        container[Columns.groups] = String(data: jsonData, encoding: .utf8) ?? "[]"
        container[Columns.version] = version
        container[Columns.installedAt] = installedAt
        container[Columns.updatedAt] = updatedAt
    }
}
