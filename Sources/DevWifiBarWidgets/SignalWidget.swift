import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct SignalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.signal", provider: SnapshotProvider()) { entry in
            SignalWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Signal")
        .description("Quality bar, RSSI, and channel.")
        .supportedFamilies([.systemSmall])
    }
}

struct SignalWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Signal", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                Text(snapshot.signalQuality?.rawValue ?? (snapshot.powerOn ? "No signal" : "Wi-Fi off"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                SignalMeter(
                    filled: snapshot.signalQuality?.segments ?? 0,
                    color: Theme.color(for: snapshot.signalQuality)
                )

                HStack(alignment: .top) {
                    detail("Channel", snapshot.channel.map { $0 > 0 ? "\($0)" : "\u{2014}" } ?? "\u{2014}")
                    detail("RSSI", Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 12).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
