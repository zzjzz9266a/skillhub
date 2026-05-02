import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var deleteConfirmation: Source?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sources")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Button(action: { viewModel.selectedSourceId = nil }) {
                        HStack {
                            Image(systemName: "tray.full")
                            Text("All Skills")
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(6)
                        .background(viewModel.selectedSourceId == nil ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.sources) { source in
                        Button(action: { viewModel.selectedSourceId = source.id }) {
                            HStack {
                                Image(systemName: "shippingbox")
                                Text(source.label)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(6)
                            .background(viewModel.selectedSourceId == source.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteConfirmation = source
                            } label: {
                                Label("Delete \"\(source.label)\"", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()
                .padding(.vertical, 8)

            Text("Agents")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(viewModel.agents) { agent in
                HStack {
                    Circle()
                        .fill(agentStatusColor(agent))
                        .frame(width: 8, height: 8)
                    Text(agent.name)
                        .lineLimit(1)
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }

            Spacer()
        }
        .frame(minWidth: 180)
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

    private func agentStatusColor(_ agent: Agent) -> Color {
        if agent.hotReloadSupported { return .green }
        return .yellow
    }
}
