import SwiftUI

struct FooterStatusBar: View {
    @ObservedObject var viewModel: AppViewModel

    private var allEnabledCount: Int {
        viewModel.agentSkillStates.values
            .flatMap { $0.values }
            .filter { $0 }
            .count
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                statItem(value: viewModel.skills.count, label: "skills")
                divider
                statItem(value: viewModel.visibleAgents.count, label: "visible agents")
                divider
                statItem(value: allEnabledCount, label: "active")
            }
            .padding(.leading, 14)

            Spacer()

            syncIndicator
                .padding(.trailing, 14)
        }
        .frame(height: 28)
        .background {
            VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) { Divider() }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 10)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    @ViewBuilder
    private var syncIndicator: some View {
        if viewModel.isResolving || viewModel.isInstalling {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(viewModel.isResolving ? "Loading source..." : "Installing skills...")
            }
        } else if viewModel.statusText.hasPrefix("Resolve failed") || viewModel.statusText.hasPrefix("Install failed") {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
                Text(viewModel.statusText)
                    .lineLimit(1)
                    .foregroundStyle(.orange)
            }
        } else {
            switch viewModel.syncStatus {
            case .idle:
                EmptyView()
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    Text("Syncing…")
                }
            case .ok(let date):
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 10))
                        Text("All in sync")
                            .foregroundStyle(Color(red: 0.18, green: 0.82, blue: 0.34))
                    }
                    divider
                    Text("Last update \(relativeTime(date))")
                }
            case .error(let msg):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(msg)
                        .lineLimit(1)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
