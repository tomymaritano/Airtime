import DevWifiCore
import DevWifiUI
import SwiftUI

struct LatencySection: View {
    let latencyMs: Double?
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latency")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            SparklineView(values: history, color: barColor)
                .frame(height: 28)

            HStack {
                Text(Format.latency(latencyMs))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(barColor)
                Spacer()
                Text("1.1.1.1")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private var barColor: Color {
        guard let latencyMs else { return Color.white.opacity(0.35) }
        if latencyMs >= AIBrief.latencyHighMs { return Theme.ok }
        if latencyMs >= AIBrief.latencyClearMs { return .orange }
        return Theme.ok
    }
}
