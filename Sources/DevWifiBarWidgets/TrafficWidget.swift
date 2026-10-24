import DevWifiCore
import SwiftUI
import WidgetKit

struct TrafficWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.traffic", provider: SnapshotProvider()) { entry in
            TrafficWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) History")
        .description("RX/TX sparkline with session totals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrafficWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Traffic", subtitle: snapshot.displayName, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetSparkline(values: snapshot.downloadHistory)
                    .frame(height: family == .systemMedium ? 36 : 24)
                HStack {
                    Label(Format.mbps(snapshot.downloadMbps), systemImage: "arrow.down")
                    Spacer()
                    Label(Format.mbps(snapshot.uploadMbps), systemImage: "arrow.up")
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
    }
}
