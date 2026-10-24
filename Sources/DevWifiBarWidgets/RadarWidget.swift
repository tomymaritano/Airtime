import DevWifiCore
import SwiftUI
import WidgetKit

struct RadarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.radar", provider: SnapshotProvider()) { entry in
            RadarWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Radar")
        .description("Whether lag is Wi-Fi or an LLM on the uplink.")
        .supportedFamilies([.systemMedium])
    }
}

struct RadarWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "On the link", subtitle: snapshot.diagnosisTitle.uppercased(), offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 6) {
                if let app = snapshot.topApp {
                    Text(app)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Text(ProductName.openPrompt)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetTheme.secondary)
                }
                Text(snapshot.diagnosisReason)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.secondary)
                    .lineLimit(3)
            }
        }
    }
}
