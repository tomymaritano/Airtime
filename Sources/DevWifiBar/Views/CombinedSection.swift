import DevWifiCore
import DevWifiUI
import SwiftUI

/// Dense density: signal, traffic and ping in one row.
struct CombinedSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                StatusDot(color: Theme.color(for: snapshot.wifi.quality))
                Text(snapshot.wifi.quality?.rawValue ?? "No signal")
            }
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
        .card(padding: 10)
        .accessibilityElement(children: .combine)
    }
}
