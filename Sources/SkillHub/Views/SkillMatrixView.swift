import SwiftUI
import AppKit

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var popoverSkillId: Int64? = nil
    @State private var hoveredSourceId: Int64? = nil
    @State private var hoveredSkillId: Int64? = nil
    @State private var skillColumnWidth: CGFloat = 200

    private let agentColumnWidth: CGFloat = 68

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

            GeometryReader { geo in
                let treeWidth = computeSkillColumnWidth(tree: tree)
                let totalContentWidth = treeWidth + CGFloat(viewModel.visibleAgents.count) * agentColumnWidth
                let needsHScroll = totalContentWidth > geo.size.width

                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        if needsHScroll {
                            ScrollView(.horizontal, showsIndicators: true) {
                                fullWidthContent(tree: tree, width: treeWidth)
                            }
                        } else {
                            fullWidthContent(tree: tree, width: treeWidth)
                        }
                        Rectangle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: treeWidth)
                            .frame(maxHeight: .infinity, alignment: .top)
                        frozenSkillColumn(tree: tree, width: treeWidth)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 18)
        }
    }

    // MARK: - Skill column width calculation

    private func computeSkillColumnWidth(tree: [(source: Source, groups: [(name: String, skills: [Skill])])]) -> CGFloat {
        var maxWidth: CGFloat = 0
        let font = NSFont.systemFont(ofSize: 13)
        let boldFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        for item in tree {
            let sourceW = ceil((item.source.label as NSString).size(withAttributes: [.font: boldFont]).width)
            maxWidth = max(maxWidth, sourceW)
            for group in item.groups {
                let groupW = ceil((displayName(for: group.name) as NSString).size(withAttributes: [.font: font]).width)
                maxWidth = max(maxWidth, groupW)
                for skill in group.skills {
                    let skillName = displayName(for: skill, sourceLabel: item.source.label)
                    let skillW = ceil((skillName as NSString).size(withAttributes: [.font: font]).width)
                    maxWidth = max(maxWidth, skillW)
                }
            }
        }
        return max(maxWidth + 49 + 24, 120)
    }

    // MARK: - Full-width matrix content

    private func fullWidthContent(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        VStack(spacing: 0) {
            fullWidthHeader(width: width)
            Divider()
            fullWidthRows(tree: tree, width: width)
        }
    }

    private func fullWidthHeader(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width, alignment: .leading)
            ForEach(viewModel.visibleAgents) { agent in
                Text(agent.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(width: agentColumnWidth, alignment: .center)
            }
        }
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private func fullWidthRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        ForEach(tree, id: \.source.id) { item in
            fullWidthForSource(source: item.source, groups: item.groups, width: width)
            Divider()
        }
    }

    @ViewBuilder
    private func fullWidthForSource(source: Source, groups: [(name: String, skills: [Skill])], width: CGFloat) -> some View {
        let isExpanded = viewModel.isSourceExpanded(sourceId: source.id)

        VStack(alignment: .leading, spacing: 0) {
            fullWidthSourceHeader(source: source, width: width)
            if isExpanded {
                if groups.count == 1 && groups.first?.name == "ungrouped" {
                    ForEach(groups.first!.skills) { skill in
                        fullWidthSkillRow(skill: skill, width: width)
                    }
                } else {
                    ForEach(groups, id: \.name) { group in
                        fullWidthForGroup(source: source, groupName: group.name, skills: group.skills, width: width)
                    }
                }
            }
        }
    }

    private func fullWidthSourceHeader(source: Source, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width, alignment: .leading)
            ForEach(viewModel.visibleAgents) { agent in
                let state = viewModel.sourceToggleState(sourceId: source.id, agentId: agent.id)
                TriStateToggle(state: state) { enable in
                    viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: enable)
                }
                .frame(width: agentColumnWidth)
            }
        }
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    @ViewBuilder
    private func fullWidthForGroup(source: Source, groupName: String, skills: [Skill], width: CGFloat) -> some View {
        let isExpanded = viewModel.isGroupExpanded(sourceId: source.id, groupName: groupName)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: width, alignment: .leading)
                ForEach(viewModel.visibleAgents) { agent in
                    let state = viewModel.groupToggleState(sourceId: source.id, groupName: groupName, agentId: agent.id)
                    TriStateToggle(state: state) { enable in
                        viewModel.toggleGroup(sourceId: source.id, groupName: groupName, agentId: agent.id, enabled: enable)
                    }
                    .frame(width: agentColumnWidth)
                }
            }
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))

            if isExpanded {
                ForEach(skills) { skill in
                    fullWidthSkillRow(skill: skill, width: width)
                }
            }
        }
    }

    private func fullWidthSkillRow(skill: Skill, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width, alignment: .leading)
            ForEach(viewModel.visibleAgents) { agent in
                let enabled = viewModel.agentSkillStates[agent.id]?[skill.id] ?? false
                SkillCellToggle(enabled: enabled) {
                    viewModel.toggleSkill(skillId: skill.id, agentId: agent.id, enabled: !enabled)
                }
                .frame(width: agentColumnWidth)
            }
        }
        .frame(height: 34)
    }

    // MARK: - Frozen skill column (overlay)

    private func frozenSkillColumn(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        VStack(spacing: 0) {
            frozenHeader(width: width)
            Divider()
            frozenSkillRows(tree: tree, width: width)
        }
        .frame(width: width)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func frozenHeader(width: CGFloat) -> some View {
        Text("Skill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private func frozenSkillRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        ForEach(tree, id: \.source.id) { item in
            frozenSourceRow(source: item.source, groups: item.groups, width: width)
            Divider()
        }
    }

    @ViewBuilder
    private func frozenSourceRow(source: Source, groups: [(name: String, skills: [Skill])], width: CGFloat) -> some View {
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
            .frame(width: width, alignment: .leading)
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
                        frozenSkillName(skill: skill, sourceLabel: source.label, width: width)
                    }
                } else {
                    ForEach(groups, id: \.name) { group in
                        frozenGroupRow(source: source, groupName: group.name, skills: group.skills, width: width)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func frozenGroupRow(source: Source, groupName: String, skills: [Skill], width: CGFloat) -> some View {
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
                .frame(width: width, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))

            if isExpanded {
                ForEach(skills) { skill in
                    frozenSkillName(skill: skill, sourceLabel: source.label, width: width)
                }
            }
        }
    }

    private func frozenSkillName(skill: Skill, sourceLabel: String, width: CGFloat) -> some View {
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
        .frame(width: width, alignment: .leading)
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
            }
        }
        .frame(minWidth: 200, idealWidth: 320, maxWidth: 450, alignment: .leading)
        .padding(12)
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
            .labelsHidden().toggleStyle(.switch).controlSize(.mini).frame(width: 68)
    }
}

private struct TriStateToggle: View {
    let state: Bool?
    let onToggle: (Bool) -> Void
    var body: some View {
        Toggle(isOn: Binding(get: { state == true }, set: { onToggle($0) })) {}
            .labelsHidden().toggleStyle(.switch).controlSize(.mini).frame(width: 68)
    }
}