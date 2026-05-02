import SwiftUI
import AppKit

struct InstallBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            TextField("Paste Git URL to install skills...", text: $viewModel.installInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.install()
                }

            Button("Browse…") {
                browseLocalSkill()
            }

            Button("Install") {
                viewModel.install()
            }
            .disabled(viewModel.installInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isResolving)
            .keyboardShortcut(.return, modifiers: [.command])

            Spacer()

            if viewModel.isResolving {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func browseLocalSkill() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Skill Directory"
        panel.message = "Select a folder that contains SKILL.md files, or a single skill folder."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        viewModel.installInput = url.path
        viewModel.install()
    }
}
