import DevWifiCore
import DevWifiUI
import SwiftUI

/// Dense density — signal + traffic + ping in one block.
struct CombinedSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Combined")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                if let quality = snapshot.wifi.quality {
                    Text(quality.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ok)
                }
            }

            ProgressBar(progress: snapshot.wifi.qualityPercent, color: Theme.ok)

            SparklineView(values: downloadHistory, color: Theme.down)
                .frame(height: 22)

            HStack {
                Text(Format.rssi(snapshot.wifi.rssi))
                Spacer()
                Text(Format.mbps(snapshot.downloadMbps))
                Spacer()
                Text(Format.latency(snapshot.latencyMs))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }
}
