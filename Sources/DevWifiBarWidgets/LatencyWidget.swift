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
