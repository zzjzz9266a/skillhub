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
