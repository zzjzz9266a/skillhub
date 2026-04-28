import GRDB
import Foundation

struct Source: Codable {
    var id: Int64 = 0
    var name: String
    var label: String
    var origin: String
    var installedAt: Date
}

extension Source: Identifiable {}

extension Source: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "sources"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let label = Column(CodingKeys.label)
        static let origin = Column(CodingKeys.origin)
        static let installedAt = Column(CodingKeys.installedAt)
    }

    func encode(to container: inout PersistenceContainer) {
        if id != 0 {
            container[Columns.id] = id
        }
        container[Columns.name] = name
        container[Columns.label] = label
        container[Columns.origin] = origin
        container[Columns.installedAt] = installedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
