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
