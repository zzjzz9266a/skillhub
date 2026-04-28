import Foundation
struct AgentSkill { let agentId: Int64; let skillId: Int64; let enabled: Bool }

extension AgentSkill: Identifiable {
    var id: String { "\(agentId)-\(skillId)" }
}
