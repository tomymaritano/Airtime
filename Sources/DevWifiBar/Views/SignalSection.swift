import DevWifiCore
import DevWifiUI
import SwiftUI

struct SignalSection: View {
    let wifi: WifiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Signal")
                Spacer()
                Text(Format.rssi(wifi.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }

            Text(wifi.quality?.rawValue ?? (wifi.powerOn ? "No signal" : "Wi-Fi off"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.color(for: wifi.quality))

            SignalMeter(filled: wifi.quality?.segments ?? 0, color: Theme.color(for: wifi.quality))

            HStack(alignment: .top) {
                detail("Channel", wifi.channel.map { $0 > 0 ? "\($0)" : "\u{2014}" } ?? "\u{2014}")
                detail("Radio rate", rateText)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 13).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rateText: String {
        if let rate = wifi.transmitRateMbps, rate > 0 {
            return String(format: "%.0f Mbps", rate)
        }
        return "\u{2014}"
    }
}
