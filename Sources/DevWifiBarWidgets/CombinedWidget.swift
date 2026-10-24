import DevWifiCore
import SwiftUI
import WidgetKit

struct CombinedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.combined", provider: SnapshotProvider()) { entry in
            CombinedWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Combined")
        .description("Signal, traffic, and ping in one block.")
        .supportedFamilies([.systemMedium])
    }
}

struct CombinedWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Combined", subtitle: snapshot.quality, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: snapshot.qualityPercent)
                    .tint(WidgetTheme.teal)
                WidgetSparkline(values: snapshot.downloadHistory)
                    .frame(height: 22)
                HStack {
                    Text(Format.rssi(snapshot.rssi))
                    Spacer()
                    Text(Format.mbps(snapshot.downloadMbps))
                    Spacer()
                    Text(Format.latency(snapshot.latencyMs))
                }
                .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
        }
    }
}
