import GRDB
import Foundation

struct Agent: Codable {
    var id: Int64 = 0
    var name: String
    var configPath: String?
    var detectedAt: Date
    var hotReloadSupported: Bool
    var visible: Bool
    var installed: Bool
}

extension Agent: Identifiable {}

extension Agent: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "agents"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let configPath = Column(CodingKeys.configPath)
        static let detectedAt = Column(CodingKeys.detectedAt)
        static let hotReloadSupported = Column(CodingKeys.hotReloadSupported)
        static let visible = Column(CodingKeys.visible)
        static let installed = Column(CodingKeys.installed)
    }

    func encode(to container: inout PersistenceContainer) {
        if id != 0 {
            container[Columns.id] = id
        }
        container[Columns.name] = name
        container[Columns.configPath] = configPath
        container[Columns.detectedAt] = detectedAt
        container[Columns.hotReloadSupported] = hotReloadSupported
        container[Columns.visible] = visible
        container[Columns.installed] = installed
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
