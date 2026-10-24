import DevWifiCore
import DevWifiUI
import SwiftUI

struct SignalSection: View {
    let wifi: WifiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            ProgressBar(progress: wifi.qualityPercent, color: barColor)

            HStack {
                Text("\(Format.percent(wifi.qualityPercent)) quality")
                Spacer()
                Text(Format.rssi(wifi.rssi))
                    .monospacedDigit()
            }
            .font(.system(size: 11))

            HStack {
                Text(Format.channel(wifi.channel))
                Spacer()
                Text(rateText)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondary)
        }
    }

    private var rateText: String {
        if let rate = wifi.transmitRateMbps, rate > 0 {
            return String(format: "%.0f Mbps radio", rate)
        }
        return "Radio —"
    }

    private var barColor: Color {
        switch wifi.quality {
        case .excellent, .good: return Theme.ok
        case .fair: return .orange
        case .weak, .veryWeak: return .red
        case nil: return Color.white.opacity(0.25)
        }
    }
}
