import DevWifiCore
import DevWifiUI
import SwiftUI

struct LatencySection: View {
    let latencyMs: Double?
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Latency \u{00B7} 1.1.1.1")
                Spacer()
                Text(Format.latency(latencyMs))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(forLatency: latencyMs))
            }

            SparklineView(values: history, color: Theme.color(forLatency: latencyMs), peak: max(history.max() ?? 0, 60))
                .frame(height: 40)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
        }
        .card()
    }
}
