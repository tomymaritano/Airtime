import DevWifiCore
import SwiftUI
import WidgetKit

struct LatencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.latency", provider: SnapshotProvider()) { entry in
            LatencyWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Latency")
        .description("Ping sparkline to 1.1.1.1.")
        .supportedFamilies([.systemSmall])
    }
}

struct LatencyWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Latency", subtitle: "1.1.1.1", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetSparkline(values: snapshot.latencyHistory)
                    .frame(height: 28)
                Text(Format.latency(snapshot.latencyMs))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.teal)
            }
        }
    }
}
