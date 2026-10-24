import DevWifiCore
import SwiftUI
import WidgetKit

struct SignalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.signal", provider: SnapshotProvider()) { entry in
            SignalWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Signal")
        .description("Quality bar, RSSI, and channel.")
        .supportedFamilies([.systemSmall])
    }
}

struct SignalWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Signal", subtitle: snapshot.quality, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: snapshot.qualityPercent)
                    .tint(WidgetTheme.teal)
                HStack {
                    Text(snapshot.displayName)
                    Spacer()
                    Text(Format.rssi(snapshot.rssi))
                        .monospacedDigit()
                }
                .font(.system(size: 12, weight: .medium))
                Text(Format.channel(snapshot.channel))
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.secondary)
            }
        }
    }
}
