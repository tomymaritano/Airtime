import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct TrafficWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.traffic", provider: SnapshotProvider()) { entry in
            TrafficWidgetEntryView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) History")
        .description("RX/TX sparkline with session totals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// `TrafficWidgetView` itself has no notion of widget families — only of how
/// much room it has. This wrapper is the one place that reads
/// `\.widgetFamily` and turns it into that boolean.
private struct TrafficWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        TrafficWidgetView(snapshot: snapshot, isCompact: family != .systemMedium)
    }
}
