import DevWifiCore
import DevWifiUI
import SwiftUI

struct WidgetPickerView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var layout: WidgetLayoutStore
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ProductName.display)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add or remove info. Each widget is a different density.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button("OK", action: onDone)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ok)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(galleryOrder) { widget in
                        galleryCard(widget)
                    }
                }
                .padding(14)
            }
            .frame(height: 420)
        }
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
    }

    private var galleryOrder: [PanelWidget] {
        [.metric, .signal, .traffic, .combined, .latency, .radar, .network]
    }

    private func galleryCard(_ widget: PanelWidget) -> some View {
        let added = layout.isVisible(widget)
        return Button {
            layout.setVisible(widget, visible: !added)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                preview(widget)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(added ? Theme.ok.opacity(0.7) : Color.white.opacity(0.06), lineWidth: added ? 1.5 : 1)
                    )

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.title)
                            .font(.system(size: 12, weight: .semibold))
                        Text(widget.summary)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(added ? "Added" : "Add")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(added ? Theme.ok : Theme.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func preview(_ widget: PanelWidget) -> some View {
        switch widget {
        case .metric:
            MetricSection(wifi: state.snapshot.wifi)
        case .signal:
            SignalSection(wifi: state.snapshot.wifi)
        case .traffic:
            TrafficSection(
                snapshot: state.snapshot,
                downloadHistory: state.downloadHistory,
                uploadHistory: state.uploadHistory
            )
        case .combined:
            CombinedSection(snapshot: state.snapshot, downloadHistory: state.downloadHistory)
        case .latency:
            LatencySection(latencyMs: state.snapshot.latencyMs, history: state.latencyHistory)
        case .radar:
            AISection(traffic: state.aiTraffic, diagnosis: state.aiDiagnosis, quality: state.snapshot.wifi.quality, selectedApp: $state.selectedAIApp)
        case .network:
            NetworkSection(snapshot: state.snapshot, copiedField: nil, onCopy: { _, _ in })
        }
    }
}
