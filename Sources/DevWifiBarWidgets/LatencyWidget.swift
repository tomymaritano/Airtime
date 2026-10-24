import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct LatencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.latency", provider: SnapshotProvider()) { entry in
            LatencyWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Latency")
        .description("Ping sparkline to 1.1.1.1.")
        .supportedFamilies([.systemSmall])
    }
}

struct LatencyWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Latency", trailing: "1.1.1.1", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Format.latency(snapshot.latencyMs))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))

                SparklineView(
                    values: snapshot.latencyHistory,
                    color: Theme.color(forLatency: snapshot.latencyMs),
                    peak: max(snapshot.latencyHistory.max() ?? 0, 60)
                )
                .frame(height: 28)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }
}
