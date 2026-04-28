import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: 220)

            VStack(spacing: 0) {
                if let sourceId = viewModel.selectedSourceId,
                   let source = viewModel.sources.first(where: { $0.id == sourceId }),
                   !viewModel.agents.isEmpty {
                    SourceToggleBar(source: source, viewModel: viewModel)
                }

                SkillMatrixView(viewModel: viewModel)

                InstallBarView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.refresh()
        }
    }
}

private struct SourceToggleBar: View {
    let source: Source
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text(source.label)
                .font(.headline)

            ForEach(viewModel.agents) { agent in
                let allEnabled = (viewModel.skillsForSource(source.id).allSatisfy {
                    viewModel.agentSkillStates[agent.id]?[$0.id] ?? false
                })
                Button(agent.name) {
                    viewModel.toggleSource(sourceId: source.id, agentId: agent.id, enabled: !allEnabled)
                }
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(allEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
