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
            HStack(spacing: 10) {
                statItem(value: viewModel.skills.count, label: "skills")
                divider
                statItem(value: viewModel.visibleAgents.count, label: "visible agents")
                divider
                statItem(value: allEnabledCount, label: "active")
            }
            .padding(.leading, 16)

            Spacer()

            syncIndicator
                .padding(.trailing, 16)
        }
        .frame(height: 28)
        .background {
            VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) { Divider() }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 1, height: 12)
    }

    @ViewBuilder
    private var syncIndicator: some View {
        switch viewModel.syncStatus {
        case .idle:
            EmptyView()
        case .syncing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                Text("Syncing…")
            }
        case .ok(let date):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 10))
                Text("All in sync")
                Text("·")
                Text("Updated \(date, format: .relative(presentation: .named))")
                    .foregroundStyle(.tertiary)
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
