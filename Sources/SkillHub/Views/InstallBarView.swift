import SwiftUI

struct InstallBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            TextField("Paste URL or local path to install skills...", text: $viewModel.installInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.install()
                }

            Button("Install") {
                viewModel.install()
            }
            .disabled(viewModel.installInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: [.command])

            Spacer()

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
