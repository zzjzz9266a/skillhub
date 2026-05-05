import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var deleteConfirmation: Source?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Text("SkillHub")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.leading, 8)

                sourceSection
            }
            .padding(.top, 54)
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
                        Circle()
                            .fill(agent.installed ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                        Text(agent.name)
                            .lineLimit(1)
                            .font(.system(size: 13))
                        Spacer()
                        Toggle(isOn: Binding(
                            get: { agent.visible },
                            set: { _ in viewModel.toggleAgentVisibility(agent.id) }
                        )) {}
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .help(agent.visible ? "Hide from matrix" : "Show in matrix")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .background {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
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
        sidebarButton(
            title: "All Skills",
            systemImage: "tray.full",
            isSelected: viewModel.selectedSourceId == nil
        ) {
            viewModel.selectedSourceId = nil
        }
    }

    private func sourceRow(_ source: Source) -> some View {
        sidebarButton(
            title: source.label,
            systemImage: "shippingbox",
            isSelected: viewModel.selectedSourceId == source.id
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

    private func sidebarButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
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
