import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit

struct TrafficWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.traffic", provider: SnapshotProvider()) { entry in
            TrafficWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.background }
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
        WidgetCard(title: "Traffic", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(uploadColor)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .lineLimit(1)

                ZStack {
                    SparklineView(values: snapshot.downloadHistory, color: Theme.down, peak: peak)
                    SparklineView(values: snapshot.uploadHistory, color: Theme.load, peak: peak)
                }
                .frame(height: family == .systemMedium ? 44 : 26)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }

    private var peak: Double {
        max(snapshot.downloadHistory.max() ?? 0, snapshot.uploadHistory.max() ?? 0, AIBrief.saturateMbps)
    }

    private var uploadColor: Color {
        Theme.color(forUpload: snapshot.uploadMbps)
    }
}
