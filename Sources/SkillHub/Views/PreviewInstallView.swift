import SwiftUI

struct PreviewInstallView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Install Skills")
                    .font(.title2.weight(.semibold))
                Text("\"\(viewModel.previewSourceLabel)\"")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if viewModel.previewIsReinstall {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This source is already installed. Reinstalling will replace all its skills.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            if viewModel.previewSkills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("No skills found")
                        .font(.headline)
                    Text("No SKILL.md files were found in this source.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text("\(viewModel.previewSkills.count) skill\(viewModel.previewSkills.count == 1 ? "" : "s") found")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.previewSkills.indices, id: \.self) { index in
                            let skill = viewModel.previewSkills[index]
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.secondary)
                                Text(skill.name)
                                    .font(.body)
                                if !skill.groups.isEmpty {
                                    Text("→ \(skill.groups.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 300)
            }

            if viewModel.statusText.hasPrefix("Install failed") {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    viewModel.cancelPreview()
                }
                .keyboardShortcut(.escape)
                .disabled(viewModel.isInstalling)

                Spacer()

                if viewModel.isInstalling {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.65)
                            .frame(width: 14, height: 14)
                        Text("Installing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    viewModel.confirmInstall()
                } label: {
                    Text(viewModel.previewIsReinstall ? "Reinstall" : "Install")
                }
                .disabled(viewModel.previewSkills.isEmpty || viewModel.isInstalling)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 420, height: 440)
    }
}
