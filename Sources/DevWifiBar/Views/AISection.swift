import DevWifiCore
import DevWifiUI
import SwiftUI

/// "On the link": the verdict, its three chips, and the AI apps using the link.
struct AISection: View {
    let traffic: AITrafficSnapshot
    let diagnosis: AIDiagnosis
    let quality: SignalQuality?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(text: "On the link")
                Spacer()
                if traffic.activeCount > 0 {
                    Text("\(traffic.activeCount) live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .help("Process names and destinations only. No packet payloads.")

            if !diagnosis.evidence.isEmpty {
                HStack(spacing: 6) {
                    ForEach(diagnosis.evidence) { item in
                        EvidenceChip(label: item.label, value: item.value, tint: tint(for: item))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: diagnosis.kind))
                    Text(diagnosis.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color(for: diagnosis.kind))
                }
                Text(diagnosis.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.body)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if !traffic.topFlows.isEmpty {
                VStack(spacing: 8) {
                    ForEach(traffic.topFlows) { flow in
                        AIAppRow(
                            flow: flow,
                            hasBandwidth: traffic.hasBandwidth,
                            share: share(of: flow),
                            barColor: diagnosis.kind == .saturated ? Theme.load : Theme.secondary
                        )
                    }
                }
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
        .card()
    }

    /// Signal and Ping carry their own scales; anything else is only interesting when tripped.
    private func tint(for item: AIEvidence) -> ChipTint {
        switch item.label {
        case "Signal":
            return .semantic(Theme.color(for: quality))
        case "Ping":
            return .semantic(item.tripped ? Theme.load : Theme.ok)
        default:
            return item.tripped ? .semantic(Theme.load) : .neutral
        }
    }

    /// Upload share, scaled so a lone small flow does not fill the bar.
    private func share(of flow: AIFlow) -> Double {
        let total = traffic.topFlows.reduce(0) { $0 + ($1.uploadMbps ?? 0) }
        let scale = max(total, AIBrief.saturateMbps)
        return min(max((flow.uploadMbps ?? 0) / scale, 0.03), 1)
    }
}

private struct AIAppRow: View {
    let flow: AIFlow
    let hasBandwidth: Bool
    let share: Double
    let barColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ProviderMark(app: flow.app)
                .frame(width: 14, height: 14)
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(flow.app)
                        .font(.system(size: 13, weight: .regular))
                    Spacer(minLength: 8)
                    Text(rate)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.body)
                        .lineLimit(1)
                }
                if hasBandwidth {
                    ShareBar(share: share, color: barColor)
                }
            }
        }
        .accessibilityLabel("\(flow.app), \(rate)")
    }

    private var rate: String {
        guard hasBandwidth, flow.uploadMbps != nil || flow.downloadMbps != nil else {
            return flow.detail == flow.app ? "" : flow.detail
        }
        let up = String(format: "%.1f", flow.uploadMbps ?? 0)
        let down = String(format: "%.1f", flow.downloadMbps ?? 0)
        return "\(up) \u{2191}  \(down) \u{2193}"
    }
}
