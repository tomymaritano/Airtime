import DevWifiCore
import SwiftUI
import WidgetKit

struct MetricWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.metric", provider: SnapshotProvider()) { entry in
            MetricWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Metric")
        .description("One number: quality and RSSI.")
        .supportedFamilies([.systemSmall])
    }
}

struct MetricWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Metric", subtitle: snapshot.quality, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Format.rssi(snapshot.rssi))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.teal)
                Text(snapshot.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.secondary)
                    .lineLimit(1)
            }
        }
    }
}
