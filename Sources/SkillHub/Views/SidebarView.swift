import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var deleteConfirmation: Source?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                sourceSection
            }
            .padding(.top, 14)
            .padding(.horizontal, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    allSkillsRow

                    ForEach(viewModel.sources) { source in
                        sourceRow(source)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            Spacer(minLength: 12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Agents")

                ForEach(viewModel.agents) { agent in
                    HStack(spacing: 8) {
                        AgentLogoView(agentName: agent.name, installed: agent.installed)
                            .frame(width: 20, height: 20)

                        Text(agent.name)
                            .lineLimit(1)
                            .font(.system(size: 13))
                            .foregroundStyle(agent.installed ? .primary : .secondary)

                        Spacer()

                        VisibilityCheckbox(isChecked: agent.visible) {
                            viewModel.toggleAgentVisibility(agent.id)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .help(agent.visible ? "Hide from matrix" : "Show in matrix")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .background {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) {
            Divider()
        }
        .alert("Delete Source", isPresented: Binding(
            get: { deleteConfirmation != nil },
            set: { if !$0 { deleteConfirmation = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let source = deleteConfirmation {
                    viewModel.deleteSource(source.id)
                    deleteConfirmation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmation = nil
            }
        } message: {
            if let source = deleteConfirmation {
                Text("Remove \"\(source.label)\" and all its skills from SkillHub? This will not delete the original source files.")
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Sources")
        }
    }

    private var allSkillsRow: some View {
        let count = viewModel.searchFilteredAllSkills.count
        return sidebarButton(
            title: "All Skills",
            systemImage: "square.grid.2x2",
            isSelected: viewModel.selectedSourceId == nil,
            count: count
        ) {
            viewModel.selectedSourceId = nil
        }
    }

    private func sourceRow(_ source: Source) -> some View {
        let count = viewModel.searchFilteredAllSkills.filter { $0.sourceId == source.id }.count
        return sidebarButton(
            title: source.label,
            systemImage: "folder",
            isSelected: viewModel.selectedSourceId == source.id,
            count: count
        ) {
            viewModel.selectedSourceId = source.id
        }
        .contextMenu {
            if SourceParser.parse(source.origin) != nil {
                Button {
                    viewModel.updateSource(source.id)
                } label: {
                    Label("Update", systemImage: "arrow.clockwise")
                }
                Divider()
            }
            Button(role: .destructive) {
                deleteConfirmation = source
            } label: {
                Label("Delete \"\(source.label)\"", systemImage: "trash")
            }
        }
    }

    private func sidebarButton(title: String, systemImage: String, isSelected: Bool, count: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .frame(width: 16)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color(nsColor: .tertiaryLabelColor))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isSelected ? Color.white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
    }

}
