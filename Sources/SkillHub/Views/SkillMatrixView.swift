import SwiftUI

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.agents.isEmpty {
            emptyAgentState
        } else if viewModel.skills.isEmpty {
            emptySkillState
        } else {
            matrixContent
        }
    }

    // MARK: - Empty states

    private var emptyAgentState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No agents detected")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Install an AI coding agent (Claude Code, OpenCode, etc.) to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySkillState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No skills installed")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Paste a Git URL or browse for a local folder to install skills")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Matrix

    private var matrixContent: some View {
        let tree = viewModel.buildTree()

        return ScrollView([.vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Column header
                HStack(spacing: 0) {
                    Text("Skill")
                        .font(.headline)
                        .frame(width: 240, alignment: .leading)
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

                // Tree rows
                ForEach(tree, id: \.source.id) { item in
                    SourceRow(source: item.source, groups: item.groups)
                    Divider()
                }
            }
        }
    }

    // MARK: - Source Row

    @ViewBuilder
    private func SourceRow(source: Source, groups: [(name: String, skills: [Skill])]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source header
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox")
                        .font(.caption)
                    Text(source.label)
                        .font(.body.weight(.semibold))
                }
                .frame(width: 240, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                ForEach(viewModel.agents) { agent in
                    let state = viewModel.sourceToggleState(sourceId: source.id, agentId: agent.id)
                    TriStateToggle(
                        state: state,
                        onToggle: { enable in
                            viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: enable)
                        }
                    )
                    .frame(width: 80)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            // Groups
            ForEach(groups, id: \.name) { group in
                GroupSection(source: source, groupName: group.name, skills: group.skills)
            }
        }
    }

    // MARK: - Group Section

    @ViewBuilder
    private func GroupSection(source: Source, groupName: String, skills: [Skill]) -> some View {
        let isExpanded = viewModel.isGroupExpanded(sourceId: source.id, groupName: groupName)

        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.toggleGroupExpanded(sourceId: source.id, groupName: groupName)
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.medium))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "folder")
                        .font(.caption)
                    Text(groupName)
                        .font(.body)
                    Text("(\(skills.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 240, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)

                ForEach(viewModel.agents) { agent in
                    let state = viewModel.groupToggleState(sourceId: source.id, groupName: groupName, agentId: agent.id)
                    TriStateToggle(
                        state: state,
                        onToggle: { enable in
                            viewModel.toggleGroup(sourceId: source.id, groupName: groupName, agentId: agent.id, enabled: enable)
                        }
                    )
                    .frame(width: 80)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))

            // Skill rows (when expanded)
            if isExpanded {
                ForEach(skills) { skill in
                    SkillRow(skill: skill)
                }
            }
        }
    }

    // MARK: - Skill Row

    @ViewBuilder
    private func SkillRow(skill: Skill) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(skill.name)
                    .font(.body)
            }
            .frame(width: 240, alignment: .leading)
            .padding(.leading, 44)
            .padding(.trailing, 8)
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
    }
}

// MARK: - Tri-state Toggle

private struct TriStateToggle: View {
    /// true = all enabled, false = all disabled, nil = mixed
    let state: Bool?
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: {
            // If mixed or all disabled → enable all; if all enabled → disable all
            onToggle(!(state == true))
        }) {
            Circle()
                .fill(stateColor)
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
    }

    private var stateColor: Color {
        switch state {
        case true:  return .green
        case false: return .secondary.opacity(0.4)
        case nil:   return .yellow
        }
    }
}
