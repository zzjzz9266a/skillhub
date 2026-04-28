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
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Skill")
                            .font(.headline)
                            .frame(width: 200, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        ForEach(viewModel.agents) { agent in
                            Text(agent.name)
                                .font(.headline)
                                .frame(width: 80, alignment: .center)
                                .padding(.vertical, 4)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    ForEach(viewModel.filteredSkills) { skill in
                        HStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(skill.name)
                                        .font(.body)
                                    if !skill.groups.isEmpty {
                                        Text(skill.groups.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(width: 200, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)

                            ForEach(viewModel.agents) { agent in
                                let enabled = viewModel.agentSkillStates[agent.id]?[skill.id] ?? false
                                Toggle("", isOn: Binding(
                                    get: { enabled },
                                    set: { newValue in
                                        viewModel.toggleSkill(skillId: skill.id, agentId: agent.id, enabled: newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .frame(width: 80)
                            }
                        }

                        Divider()
                    }
                }
            }
        }
    }
}
