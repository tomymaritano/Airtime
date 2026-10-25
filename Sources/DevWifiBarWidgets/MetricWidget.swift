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
