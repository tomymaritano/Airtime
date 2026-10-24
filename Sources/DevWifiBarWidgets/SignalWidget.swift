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
