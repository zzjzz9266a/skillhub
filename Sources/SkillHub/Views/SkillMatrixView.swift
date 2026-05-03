import SwiftUI

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.visibleAgents.isEmpty {
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

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Matrix")
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(viewModel.filteredSkills.count) skills across \(viewModel.visibleAgents.count) agents")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 18)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Skill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        ForEach(viewModel.visibleAgents) { agent in
                            Text(agent.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 104, alignment: .center)
                        }
                    }
                    .frame(height: 34)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))

                    Divider()

                    ForEach(tree, id: \.source.id) { item in
                        SourceRow(source: item.source, groups: item.groups)
                        Divider()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Source Row

    @ViewBuilder
    private func SourceRow(source: Source, groups: [(name: String, skills: [Skill])]) -> some View {
        let isExpanded = viewModel.isSourceExpanded(sourceId: source.id)

        VStack(alignment: .leading, spacing: 0) {
            // Source header
            HStack(spacing: 0) {
                Button {
                    viewModel.toggleSourceExpanded(sourceId: source.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 16, height: 16)
                        Image(systemName: "shippingbox")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(source.label)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(viewModel.visibleAgents) { agent in
                    let state = viewModel.sourceToggleState(sourceId: source.id, agentId: agent.id)
                    TriStateToggle(
                        state: state,
                        onToggle: { enable in
                            viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: enable)
                        }
                    )
                    .frame(width: 104)
                }
            }
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))

            // Groups or flat skills
            if isExpanded {
                if groups.count == 1 && groups.first?.name == "ungrouped" {
                    ForEach(groups.first!.skills) { skill in
                        SkillRow(skill: skill, sourceLabel: source.label)
                    }
                } else {
                    ForEach(groups, id: \.name) { group in
                        GroupSection(source: source, groupName: group.name, skills: group.skills)
                    }
                }
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
                Button {
                    viewModel.toggleGroupExpanded(sourceId: source.id, groupName: groupName)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 16, height: 16)
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(displayName(for: groupName))
                            .font(.system(size: 13))
                            .lineLimit(1)
                        Text("(\(skills.count))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse group" : "Expand group")

                ForEach(viewModel.visibleAgents) { agent in
                    let state = viewModel.groupToggleState(sourceId: source.id, groupName: groupName, agentId: agent.id)
                    TriStateToggle(
                        state: state,
                        onToggle: { enable in
                            viewModel.toggleGroup(sourceId: source.id, groupName: groupName, agentId: agent.id, enabled: enable)
                        }
                    )
                    .frame(width: 104)
                }
            }
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))

            // Skill rows (when expanded)
            if isExpanded {
                ForEach(skills) { skill in
                    SkillRow(skill: skill, sourceLabel: source.label)
                }
            }
        }
    }

    private func displayName(for groupName: String) -> String {
        groupName == "ungrouped" ? "Ungrouped" : groupName
    }

    // MARK: - Skill Row

    @ViewBuilder
    private func SkillRow(skill: Skill, sourceLabel: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(displayName(for: skill, sourceLabel: sourceLabel))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 38)
            .padding(.trailing, 8)

            ForEach(viewModel.visibleAgents) { agent in
                let enabled = viewModel.agentSkillStates[agent.id]?[skill.id] ?? false
                SkillCellToggle(enabled: enabled) {
                    viewModel.toggleSkill(skillId: skill.id, agentId: agent.id, enabled: !enabled)
                }
                .frame(width: 104)
            }
        }
        .frame(height: 34)
    }

    private func displayName(for skill: Skill, sourceLabel: String) -> String {
        if skill.name.hasPrefix("skillhub-clone-") {
            return sourceLabel
        }
        return skill.name
    }
}

private struct SkillCellToggle: View {
    let enabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(enabled ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor).opacity(0.001))
                    .frame(width: 76, height: 26)
                Image(systemName: enabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(enabled ? Color.accentColor : Color.secondary.opacity(0.72))
            }
            .frame(width: 104, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(enabled ? "Disable skill" : "Enable skill")
    }
}

// MARK: - Tri-state Toggle

private struct TriStateToggle: View {
    /// true = all enabled, false = all disabled, nil = mixed
    let state: Bool?
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            // If mixed or all disabled → enable all; if all enabled → disable all
            onToggle(!(state == true))
        } label: {
            ZStack {
                Circle()
                    .fill(stateColor.opacity(state == nil ? 0.75 : 1))
                    .frame(width: 12, height: 12)
                if state == nil {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 104, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var stateColor: Color {
        switch state {
        case true:  return .green
        case false: return .secondary.opacity(0.32)
        case nil:   return .orange
        }
    }
}
