import SwiftUI
import AppKit

struct InstallBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var installFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Paste Git URL to install skills...", text: $viewModel.installInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(maxWidth: 360)
                .focused($installFieldFocused)
                .onSubmit {
                    viewModel.install()
                }

            Button("Browse…") {
                browseLocalSkill()
            }
            .font(.system(size: 13))

            Button("Install") {
                viewModel.install()
            }
            .disabled(viewModel.installInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isResolving)
            .keyboardShortcut(.return, modifiers: [.command])
            .font(.system(size: 13, weight: .medium))

            Spacer()

            if viewModel.isResolving {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .withinWindow)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    installFieldFocused = false
                }
        }
        .overlay(alignment: .top) {
            Divider()
        }
        .onAppear {
            installFieldFocused = false
        }
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
