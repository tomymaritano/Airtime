import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct NetworkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.network", provider: SnapshotProvider()) { entry in
            NetworkWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Network")
        .description("IP, gateway, DNS, and latency.")
        .supportedFamilies([.systemMedium])
    }
}
