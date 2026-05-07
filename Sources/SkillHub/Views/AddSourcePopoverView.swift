import SwiftUI
import AppKit

struct AddSourcePopoverView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add source")
                .font(.system(size: 13, weight: .semibold))

            Text("Paste a Git URL, npm package name, or choose a local folder.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("https://github.com/…  ·  @scope/pkg  ·  /path/…",
                          text: $viewModel.installInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .focused($inputFocused)
                    .onSubmit { install() }

                Button("Browse…") { browseLocalSkill() }
                    .font(.system(size: 12))
            }

            HStack {
                if viewModel.isResolving {
                    ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                    Text("Resolving…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    viewModel.installInput = ""
                    viewModel.showAddSourcePopover = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Install") {
                    install()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.installInput.trimmingCharacters(in: .whitespaces).isEmpty
                          || viewModel.isResolving)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear { inputFocused = true }
    }

    private func install() {
        viewModel.install()
        viewModel.showAddSourcePopover = false
    }

    private func browseLocalSkill() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Skill Directory"
        panel.message = "Select a folder that contains SKILL.md files."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.installInput = url.path
        install()
    }
}
