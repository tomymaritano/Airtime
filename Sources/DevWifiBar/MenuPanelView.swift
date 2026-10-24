import AppKit
import DevWifiCore
import DevWifiUI
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var layout: WidgetLayoutStore
    @State private var editingWidgets = false

    var body: some View {
        Group {
            if editingWidgets {
                WidgetPickerView(layout: layout) {
                    editingWidgets = false
                }
                .environment(\.colorScheme, .dark)
            } else {
                panel
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HeaderView(snapshot: state.snapshot)

            ForEach(layout.visible) { widget in
                widgetView(widget)
            }

            FooterView(
                launchAtLogin: $state.launchAtLoginEnabled,
                canManageLogin: LaunchAtLogin.isBundled,
                onLaunchAtLogin: { state.toggleLaunchAtLogin($0) },
                onWidgets: { editingWidgets = true },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func widgetView(_ widget: PanelWidget) -> some View {
        switch widget {
        case .signal:
            SignalSection(wifi: state.snapshot.wifi)
        case .traffic:
            TrafficSection(
                snapshot: state.snapshot,
                downloadHistory: state.downloadHistory,
                uploadHistory: state.uploadHistory
            )
        case .radar:
            AISection(
                traffic: state.aiTraffic,
                diagnosis: state.aiDiagnosis,
                quality: state.snapshot.wifi.quality
            )
        case .network:
            NetworkSection(
                snapshot: state.snapshot,
                copiedField: state.copiedField,
                onCopy: { value, field in state.copy(value, field: field) }
            )
        case .latency:
            LatencySection(latencyMs: state.snapshot.latencyMs, history: state.latencyHistory)
        case .metric:
            MetricSection(wifi: state.snapshot.wifi)
        case .combined:
            CombinedSection(snapshot: state.snapshot, downloadHistory: state.downloadHistory)
        }
    }
}
