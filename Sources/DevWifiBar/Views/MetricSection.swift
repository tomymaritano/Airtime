import DevWifiCore
import DevWifiUI
import SwiftUI

/// Compact density — one number, like CodexBar Metric.
struct MetricSection: View {
    let wifi: WifiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Metric")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(wifi.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }

            Text(Format.rssi(wifi.rssi))
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.ok)

            Text(wifi.quality?.rawValue ?? "No signal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)
        }
    }
}
