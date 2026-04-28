import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

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
    }

    private func agentStatusColor(_ agent: Agent) -> Color {
        if agent.hotReloadSupported { return .green }
        return .yellow
    }
}
