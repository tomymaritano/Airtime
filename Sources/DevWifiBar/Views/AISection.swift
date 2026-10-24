import DevWifiCore
import DevWifiUI
import SwiftUI

struct AISection: View {
    let traffic: AITrafficSnapshot
    let diagnosis: AIDiagnosis
    @Binding var selectedApp: String?

    private var selected: AIFlow? {
        traffic.topFlows.first(where: { $0.app == selectedApp }) ?? traffic.topFlows.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                BrandMarkView(color: Theme.ok)
                    .frame(width: 14, height: 14)
                Text("On the link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                if traffic.activeCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.ok)
                            .frame(width: 6, height: 6)
                        Text("\(traffic.activeCount) live")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.ok)
                    }
                }
            }
            .help("Process names and destinations only. No packet payloads.")

            if !diagnosis.evidence.isEmpty {
                HStack(spacing: 6) {
                    ForEach(diagnosis.evidence) { item in
                        evidenceChip(item)
                    }
                }
            }

            if traffic.topFlows.isEmpty {
                Text(diagnosis.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(traffic.topFlows) { flow in
                            AIAppChip(
                                flow: flow,
                                selected: flow.app == selected?.app,
                                action: { selectedApp = flow.app }
                            )
                        }
                    }
                }

                if let selected {
                    AIAppDetail(flow: selected, diagnosis: diagnosis)
                }
            }
        }
    }

    private func evidenceChip(_ item: AIEvidence) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.secondary)
            Text(item.value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(item.tripped ? Theme.load : .primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            item.tripped ? Theme.load.opacity(0.12) : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct AIAppChip: View {
    let flow: AIFlow
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ProviderMark(app: flow.app)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.primary)
                Text(flow.app)
                    .font(.system(size: 11, weight: .semibold))
                if flow.isStreaming {
                    Circle()
                        .fill(Theme.down)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                selected ? AIAppStyle.color(for: flow.app).opacity(0.16) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? AIAppStyle.color(for: flow.app).opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(flow.app), \(flow.statusLabel)")
    }
}

private struct AIAppDetail: View {
    let flow: AIFlow
    let diagnosis: AIDiagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                ProviderMark(app: flow.app)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.primary)
                Text(flow.app)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(diagnosis.title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(diagnosis.kind == .saturated || diagnosis.kind == .streaming ? Theme.load : Theme.secondary)
            }

            Text(diagnosis.reason)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

enum AIAppStyle {
    static func color(for app: String) -> Color {
        switch app {
        case "Cursor": return Theme.down
        case "Claude": return Color(red: 0.86, green: 0.52, blue: 0.32)
        case "Grok": return Color.white.opacity(0.85)
        case "ChatGPT", "OpenAI": return Color(red: 0.29, green: 0.78, blue: 0.55)
        case "Copilot": return Color(red: 0.35, green: 0.62, blue: 0.98)
        case "Gemini": return Color(red: 0.47, green: 0.62, blue: 0.98)
        case "Windsurf": return Color(red: 0.40, green: 0.78, blue: 0.88)
        default: return Theme.down
        }
    }
}
