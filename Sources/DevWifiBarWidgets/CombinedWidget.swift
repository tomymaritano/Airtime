import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct CombinedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.combined", provider: SnapshotProvider()) { entry in
            CombinedWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("\(ProductName.display) Combined")
        .description("Signal, traffic, and ping in one block.")
        .supportedFamilies([.systemMedium])
    }
}
