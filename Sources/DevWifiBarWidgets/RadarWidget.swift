import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct RadarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.radar", provider: SnapshotProvider()) { entry in
            RadarWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Radar")
        .description("Whether lag is Wi-Fi or an LLM on the uplink.")
        .supportedFamilies([.systemMedium])
    }
}
