import DevWifiCore
import SwiftUI
import WidgetKit

struct NetworkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.tomymaritano.devwibar.network", provider: SnapshotProvider()) { entry in
            NetworkWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("\(ProductName.display) Network")
        .description("IP, gateway, DNS, and latency.")
        .supportedFamilies([.systemMedium])
    }
}

struct NetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetChrome(title: "Network", subtitle: snapshot.displayName, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 6) {
                row("IP", snapshot.localIP.isEmpty ? "—" : snapshot.localIP)
                row("Gateway", snapshot.gateway.isEmpty ? "—" : snapshot.gateway)
                row("DNS", snapshot.dns.isEmpty ? "—" : snapshot.dns)
                row("Latency", Format.latency(snapshot.latencyMs))
            }
            .font(.system(size: 12).monospacedDigit())
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(WidgetTheme.secondary)
            Spacer()
            Text(value)
        }
    }
}
