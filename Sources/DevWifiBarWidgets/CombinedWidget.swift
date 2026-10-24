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

struct CombinedWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Combined", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.signalQuality))
                    Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    Spacer(minLength: 4)
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(Theme.color(forUpload: snapshot.uploadMbps))
                    Spacer(minLength: 4)
                    Text(Format.latency(snapshot.latencyMs))
                        .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .lineLimit(1)

                SparklineView(
                    values: snapshot.downloadHistory,
                    color: Theme.down,
                    peak: max(snapshot.downloadHistory.max() ?? 0, AIBrief.saturateMbps)
                )
                    .frame(height: 30)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.divider).frame(height: 1)
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
