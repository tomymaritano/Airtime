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

struct NetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Network", trailing: snapshot.displayName, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 7) {
                row("IP address", snapshot.localIP.isEmpty ? "\u{2014}" : snapshot.localIP)
                row("Gateway", snapshot.gateway.isEmpty ? "\u{2014}" : snapshot.gateway)
                row("DNS", snapshot.dns.isEmpty ? "\u{2014}" : snapshot.dns)
                row("Latency to 1.1.1.1", Format.latency(snapshot.latencyMs))
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
        }
    }
}
