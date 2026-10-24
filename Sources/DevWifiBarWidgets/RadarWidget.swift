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

struct RadarWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "On the link", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.diagnosisKind))
                    Text(snapshot.diagnosisTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color(for: snapshot.diagnosisKind))
                }

                Text(snapshot.diagnosisReason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.body)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let app = snapshot.topApp {
                    Text(app)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
