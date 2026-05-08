import SwiftUI
import AppKit

struct SkillMatrixView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var popoverSkillId: Int64? = nil
    @State private var hoveredSourceId: Int64? = nil
    @State private var hoveredSkillId: Int64? = nil
    @State private var skillColumnWidth: CGFloat = 200

    private let agentColumnWidth: CGFloat = 116

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
        let tree = viewModel.buildFilteredTree()

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Matrix").font(.system(size: 17, weight: .semibold))
                    Text("\(viewModel.searchFilteredSkills.count) skills · \(viewModel.visibleAgents.count) visible agents")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, 14).padding(.horizontal, 20).padding(.bottom, 10)

            GeometryReader { geo in
                let agentColumnsWidth = CGFloat(viewModel.visibleAgents.count) * agentColumnWidth
                let minSkillWidth = computeSkillColumnWidth(tree: tree)
                // 首列填满剩余空间；仅当内容超出时才横向滚动
                let needsHScroll = minSkillWidth + agentColumnsWidth > geo.size.width
                let treeWidth = needsHScroll
                    ? minSkillWidth
                    : geo.size.width - agentColumnsWidth

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
        let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

        let headerW = ceil(("SKILL" as NSString).size(withAttributes: [.font: headerFont]).width) + 40 // 20px padding each side

        for item in tree {
            // Source row: 12px padding + chevron(16) + gap(4) + icon(13) + gap(4) + text + meta(24) + action(18) + trailing(4)
            let sourceW = 12 + 16 + 4 + 13 + 4 + ceil((item.source.label as NSString).size(withAttributes: [.font: boldFont]).width) + 24 + 18 + 4
            maxWidth = max(maxWidth, sourceW)

            for group in item.groups {
                // Group row: 12px padding + chevron(16) + gap(4) + folder(13) + gap(4) + text + "(n)" + trailing(4)
                let groupNameW = ceil((displayName(for: group.name) as NSString).size(withAttributes: [.font: font]).width)
                let countW = ceil(("(\(group.skills.count))" as NSString).size(withAttributes: [.font: font]).width)
                let groupW = 12 + 16 + 4 + 13 + 4 + groupNameW + 4 + countW + 4
                maxWidth = max(maxWidth, groupW)

                for skill in group.skills {
                    let skillName = displayName(for: skill, sourceLabel: item.source.label)
                    // Skill row: 12px padding + spacer(31) + spacer(13) + gap(4) + text + info(18) + trailing(4)
                    let skillW = 12 + 31 + 13 + 4 + ceil((skillName as NSString).size(withAttributes: [.font: font]).width) + 18 + 4
                    maxWidth = max(maxWidth, skillW)
                }
            }
        }
        return max(maxWidth, headerW, 180)
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
                HStack(spacing: 5) {
                    Circle()
                        .fill(agent.installed ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(agent.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: agentColumnWidth, alignment: .center)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.5))
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func fullWidthRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        ForEach(tree, id: \.source.id) { item in
            fullWidthForSource(source: item.source, groups: item.groups, width: width)
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
                let progress = viewModel.sourceProgressState(sourceId: source.id, agentId: agent.id)
                ProgressPill(enabled: progress.enabled, total: progress.total) { enable in
                    viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: enable)
                }
                .frame(width: agentColumnWidth, alignment: .center)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.5))
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func fullWidthForGroup(source: Source, groupName: String, skills: [Skill], width: CGFloat) -> some View {
        let isExpanded = viewModel.isGroupExpanded(sourceId: source.id, groupName: groupName)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: width, alignment: .leading)
                ForEach(viewModel.visibleAgents) { agent in
                    let progress = viewModel.groupProgressState(sourceId: source.id, groupName: groupName, agentId: agent.id)
                    ProgressPill(enabled: progress.enabled, total: progress.total) { enable in
                        viewModel.toggleGroup(sourceId: source.id, groupName: groupName, agentId: agent.id, enabled: enable)
                    }
                    .frame(width: agentColumnWidth, alignment: .center)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.5))
                            .frame(width: 0.5)
                    }
                }
            }
            .frame(height: 32)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(height: 0.5)
            }

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
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.5))
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
        }
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
        Text("SKILL")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.05)
            .frame(width: width, height: 32, alignment: .leading)
            .padding(.horizontal, 20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(height: 0.5)
            }
    }

    @ViewBuilder
    private func frozenSkillRows(tree: [(source: Source, groups: [(name: String, skills: [Skill])])], width: CGFloat) -> some View {
        ForEach(tree, id: \.source.id) { item in
            frozenSourceRow(source: item.source, groups: item.groups, width: width)
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

                Image(systemName: "folder.fill").font(.system(size: 12)).foregroundStyle(Color.accentColor)
                Text(source.label).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.tail)

                Spacer(minLength: 0)

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
            }
            .padding(.horizontal, 12)
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggleSourceExpanded(sourceId: source.id) }
            .onHover { hovering in
                hoveredSourceId = hovering ? source.id : nil
            }
            .frame(height: 32)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(height: 0.5)
            }

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
                    Text(displayName(for: groupName)).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                    Text("(\(skills.count))").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(width: width, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 32)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    .frame(height: 0.5)
            }

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
            Color.clear.frame(width: 31, height: 16)
            Color.clear.frame(width: 13, height: 13)
            Text(displayName(for: skill, sourceLabel: sourceLabel))
                .font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
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
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredSkillId = hovering ? skill.id : nil
        }
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
        }
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

private struct ProgressPill: View {
    let enabled: Int
    let total: Int
    let onToggleAll: (Bool) -> Void

    private var isFull: Bool { enabled == total && total > 0 }
    private var isEmpty: Bool { enabled == 0 }
    private var isMixed: Bool { !isFull && !isEmpty }

    // Donut arc: circumference of r=5.5 circle = 2π×5.5 ≈ 34.56
    private var strokeDashOffset: CGFloat {
        total > 0 ? 34.56 * (1 - CGFloat(enabled) / CGFloat(total)) : 34.56
    }

    var body: some View {
        Button {
            onToggleAll(!isFull)
        } label: {
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 1.6)
                        .opacity(0.35)
                        .frame(width: 14, height: 14)
                    Circle()
                        .trim(from: 0, to: total > 0 ? CGFloat(enabled) / CGFloat(total) : 0)
                        .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 14, height: 14)
                }
                .foregroundStyle(isFull ? Color.white : Color.accentColor)

                Text("\(enabled)/\(total)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isFull ? Color.white : (isEmpty ? Color.secondary : Color.accentColor))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(isFull
                          ? Color.accentColor
                          : (isMixed
                             ? Color.accentColor.opacity(0.12)
                             : Color(nsColor: .quaternaryLabelColor).opacity(0.35)))
            }
        }
        .buttonStyle(.plain)
        .help(isFull ? "Click to disable all" : "Click to enable all")
        .simultaneousGesture(
            TapGesture()
                .modifiers(.option)
                .onEnded { _ in onToggleAll(false) }
        )
    }
}
