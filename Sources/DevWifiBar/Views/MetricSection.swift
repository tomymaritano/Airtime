import DevWifiCore
import DevWifiUI
import SwiftUI

/// Compact density: one number, the RSSI.
struct MetricSection: View {
    let wifi: WifiInfo

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                CardTitle(text: "Metric")
                Text(Format.rssi(wifi.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(for: wifi.quality))
            }
            Spacer()
            Text(wifi.quality?.rawValue ?? "No signal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color(for: wifi.quality))
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
