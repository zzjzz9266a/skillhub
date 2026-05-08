import SwiftUI

struct AgentLogoView: View {
    let agentName: String
    let installed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(logoBackground)
            Image(systemName: logoSymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(logoForeground)
        }
        .opacity(installed ? 1.0 : 0.45)
    }

    private var logoBackground: Color {
        switch agentName {
        case "Claude Code":   return Color(red: 0.83, green: 0.65, blue: 0.48)
        case "Codex":         return Color(red: 0.05, green: 0.05, blue: 0.05)
        case "OpenCode":      return Color(red: 0.10, green: 0.09, blue: 0.09)
        case "Gemini CLI":    return Color(red: 0.10, green: 0.45, blue: 0.91)
        case "Copilot CLI":   return Color(red: 0.14, green: 0.16, blue: 0.18)
        case "OpenClaw":      return Color(red: 0.37, green: 0.29, blue: 0.55)
        case "Hermes":        return Color(red: 0.77, green: 0.36, blue: 0.10)
        default:              return Color.secondary.opacity(0.3)
        }
    }

    private var logoSymbol: String {
        switch agentName {
        case "Claude Code":   return "c.circle"
        case "Codex":         return "circle.hexagongrid"
        case "OpenCode":      return "terminal"
        case "Gemini CLI":    return "sparkle"
        case "Copilot CLI":   return "airplane.circle"
        case "OpenClaw":      return "pawprint"
        case "Hermes":        return "envelope.wings"
        default:              return "questionmark"
        }
    }

    private var logoForeground: Color {
        .white
    }
}

struct VisibilityCheckbox: View {
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isChecked }, set: { _ in onToggle() })) {}
            .labelsHidden()
            .toggleStyle(.checkbox)
            .controlSize(.small)
    }
}
