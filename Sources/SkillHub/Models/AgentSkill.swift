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
