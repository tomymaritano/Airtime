import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct MetricWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.metric", provider: SnapshotProvider()) { entry in
            MetricWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Metric")
        .description("One number: quality and RSSI.")
        .supportedFamilies([.systemSmall])
    }
}

struct MetricWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Metric", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
