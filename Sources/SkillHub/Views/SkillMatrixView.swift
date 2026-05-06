import SwiftUI
import AppKit

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel
    @AppStorage("skillColumnWidth") private var storedWidth: Double = 200
    @GestureState private var dragOffset: CGFloat = 0
    @State private var popoverSkillId: Int64? = nil
    @State private var hoveredSourceId: Int64? = nil
    @State private var hoveredSkillId: Int64? = nil

    private var skillColumnWidth: CGFloat { CGFloat(storedWidth) }

    var body: some View {
        if viewModel.visibleAgents.isEmpty {
            emptyAgentState
        } else if viewModel.skills.isEmpty {
            emptySkillState
        } else {
            matrixContent
        }
    }

    private var emptyAgentState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.secondary)
            Text("No agents detected").font(.title3).foregroundColor(.secondary)
            Text("Install an AI coding agent to get started").font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySkillState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundColor(.secondary)
            Text("No skills installed").font(.title3).foregroundColor(.secondary)
            Text("Paste a Git URL or browse for a local folder to install skills").font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var matrixContent: some View {
        let tree = viewModel.buildTree()

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Matrix").font(.system(size: 17, weight: .semibold))
                    Text("\(viewModel.filteredSkills.count) skills across \(viewModel.visibleAgents.count) agents")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, 18).padding(.horizontal, 24).padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    fullWidthMatrix(tree: tree)
                    Rectangle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: skillColumnWidth + dragOffset)
                        .frame(maxHeight: .infinity, alignment: .top)
                    frozenSkillColumn(tree: tree)
                }
                .coordinateSpace(name: "matrixColumns")
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            }
            .padding(.horizontal, 24).padding(.bottom, 18)
        }
    }

    // MARK: - Full-width matrix (scrollable horizontally)

    private func fullWidthMatrix(tree: [(source: Source, groups: [(name: String, skills: [Skill])])]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                fullWidthHeader
                Divider()
                fullWidthRows(tree: tree)
            }
        }
    }

    private var fullWidthHeader: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(viewModel.visibleAgents) { agent in
                    Text(agent.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2).multilineTextAlignment(.center)
                        .frame(width: 104, alignment: .center)
                }
            }
        }
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private func fullWidthRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])]) -> some View {
        ForEach(tree, id: \.source.id) { item in
            fullWidthForSource(source: item.source, groups: item.groups)
            Divider()
        }
    }

    @ViewBuilder
    private func fullWidthForSource(source: Source, groups: [(name: String, skills: [Skill])]) -> some View {
        let isExpanded = viewModel.isSourceExpanded(sourceId: source.id)

        VStack(alignment: .leading, spacing: 0) {
            fullWidthSourceHeader(source: source)
            if isExpanded {
                if groups.count == 1 && groups.first?.name == "ungrouped" {
                    ForEach(groups.first!.skills) { skill in
                        fullWidthSkillRow(skill: skill)
                    }
                } else {
                    ForEach(groups, id: \.name) { group in
                        fullWidthForGroup(source: source, groupName: group.name, skills: group.skills)
                    }
                }
            }
        }
    }

    private func fullWidthSourceHeader(source: Source) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(viewModel.visibleAgents) { agent in
                    let state = viewModel.sourceToggleState(sourceId: source.id, agentId: agent.id)
                    TriStateToggle(state: state) { enable in
                        viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: enable)
                    }
                    .frame(width: 104)
                }
            }
        }
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    @ViewBuilder
    private func fullWidthForGroup(source: Source, groupName: String, skills: [Skill]) -> some View {
        let isExpanded = viewModel.isGroupExpanded(sourceId: source.id, groupName: groupName)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
                HStack(spacing: 0) {
                    ForEach(viewModel.visibleAgents) { agent in
                        let state = viewModel.groupToggleState(sourceId: source.id, groupName: groupName, agentId: agent.id)
                        TriStateToggle(state: state) { enable in
                            viewModel.toggleGroup(sourceId: source.id, groupName: groupName, agentId: agent.id, enabled: enable)
                        }
                        .frame(width: 104)
                    }
                }
            }
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))

            if isExpanded {
                ForEach(skills) { skill in
                    fullWidthSkillRow(skill: skill)
                }
            }
        }
    }

    private func fullWidthSkillRow(skill: Skill) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(viewModel.visibleAgents) { agent in
                    let enabled = viewModel.agentSkillStates[agent.id]?[skill.id] ?? false
                    SkillCellToggle(enabled: enabled) {
                        viewModel.toggleSkill(skillId: skill.id, agentId: agent.id, enabled: !enabled)
                    }
                    .frame(width: 104)
                }
            }
        }
        .frame(height: 34)
    }

    // MARK: - Frozen skill column (overlay)

    private func frozenSkillColumn(tree: [(source: Source, groups: [(name: String, skills: [Skill])])]) -> some View {
        VStack(spacing: 0) {
            frozenHeader
            Divider()
            frozenSkillRows(tree: tree)
        }
        .frame(width: skillColumnWidth + dragOffset)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .trailing) {
            dividerView
        }
    }

    private var frozenHeader: some View {
        Text("Skill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private func frozenSkillRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])]) -> some View {
        ForEach(tree, id: \.source.id) { item in
            frozenSourceRow(source: item.source, groups: item.groups)
            Divider()
        }
    }

    @ViewBuilder
    private func frozenSourceRow(source: Source, groups: [(name: String, skills: [Skill])]) -> some View {
        let isExpanded = viewModel.isSourceExpanded(sourceId: source.id)
        let isGitSource = SourceParser.parse(source.origin) != nil
        let isUpdating = viewModel.isSourceUpdating(source.id)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    viewModel.toggleSourceExpanded(sourceId: source.id)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium)).frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: "shippingbox").font(.system(size: 13)).foregroundStyle(.secondary)
                Text(source.label).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.tail)

                if isGitSource && !isUpdating && hoveredSourceId == source.id {
                    Button {
                        viewModel.updateSource(source.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Update from \(source.origin)")
                }
                if isUpdating {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 16, height: 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggleSourceExpanded(sourceId: source.id) }
            .onHover { hovering in
                hoveredSourceId = hovering ? source.id : nil
            }
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))

            if isExpanded {
                if groups.count == 1 && groups.first?.name == "ungrouped" {
                    ForEach(groups.first!.skills) { skill in
                        frozenSkillName(skill: skill, sourceLabel: source.label)
                    }
                } else {
                    ForEach(groups, id: \.name) { group in
                        frozenGroupRow(source: source, groupName: group.name, skills: group.skills)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func frozenGroupRow(source: Source, groupName: String, skills: [Skill]) -> some View {
        let isExpanded = viewModel.isGroupExpanded(sourceId: source.id, groupName: groupName)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.toggleGroupExpanded(sourceId: source.id, groupName: groupName)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium)).frame(width: 16, height: 16)
                    Image(systemName: "folder").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(displayName(for: groupName)).font(.system(size: 13)).lineLimit(1)
                    Text("(\(skills.count))").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))

            if isExpanded {
                ForEach(skills) { skill in
                    frozenSkillName(skill: skill, sourceLabel: source.label)
                }
            }
        }
    }

    private func frozenSkillName(skill: Skill, sourceLabel: String) -> some View {
        let hasDesc = skill.description != nil
        let isPopoverShown = popoverSkillId == skill.id

        return HStack(spacing: 4) {
            Color.clear.frame(width: 16, height: 16)
            Color.clear.frame(width: 13, height: 13)
            Text(displayName(for: skill, sourceLabel: sourceLabel))
                .font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
            if hasDesc && hoveredSkillId == skill.id {
                Button {
                    popoverSkillId = popoverSkillId == skill.id ? nil : skill.id
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(isPopoverShown ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { popoverSkillId == skill.id },
                    set: { if !$0 { popoverSkillId = nil } }
                )) {
                    skillPopoverContent(skill: skill)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: skillColumnWidth + dragOffset, alignment: .leading)
        .onHover { hovering in
            hoveredSkillId = hovering ? skill.id : nil
        }
        .frame(height: 34)
    }

    @ViewBuilder
    private func skillPopoverContent(skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayNameNoSource(skill: skill))
                .font(.system(size: 14, weight: .semibold))
            if let desc = skill.description {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280, alignment: .leading)
            }
        }
        .padding(12)
    }

    // MARK: - Divider

    private var dividerView: some View {
        Rectangle()
            .fill(dragOffset != 0 ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.2))
            .frame(width: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.arrow.push()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("matrixColumns"))
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let newWidth = max(120, min(500, storedWidth + Double(value.translation.width)))
                        storedWidth = newWidth
                        NSCursor.arrow.push()
                    }
            )
    }

    // MARK: - Helpers

    private func displayName(for groupName: String) -> String {
        groupName == "ungrouped" ? "Ungrouped" : groupName
    }

    private func displayName(for skill: Skill, sourceLabel: String) -> String {
        if skill.name.hasPrefix("skillhub-clone-") { return sourceLabel }
        return skill.name
    }

    private func displayNameNoSource(skill: Skill) -> String {
        skill.name.hasPrefix("skillhub-clone-") ? String(skill.name.dropFirst("skillhub-clone-".count)) : skill.name
    }
}

private struct SkillCellToggle: View {
    let enabled: Bool
    let onToggle: () -> Void
    var body: some View {
        Toggle(isOn: Binding(get: { enabled }, set: { _ in onToggle() })) {}
            .labelsHidden().toggleStyle(.switch).controlSize(.mini).frame(width: 104)
    }
}

private struct TriStateToggle: View {
    let state: Bool?
    let onToggle: (Bool) -> Void
    var body: some View {
        Toggle(isOn: Binding(get: { state == true }, set: { onToggle($0) })) {}
            .labelsHidden().toggleStyle(.switch).controlSize(.mini).frame(width: 104)
    }
}