import DevWifiCore
import DevWifiUI
import SwiftUI

/// History: download and upload on one scale, current rates, session totals.
struct TrafficSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Traffic")
                Spacer()
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(uploadColor)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }

            ZStack {
                SparklineView(values: downloadHistory, color: Theme.down, peak: peak)
                SparklineView(values: uploadHistory, color: Theme.load, peak: peak)
            }
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.divider).frame(height: 1)
            }

            HStack {
                Text("This session")
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text("\u{2193} \(Format.bytes(snapshot.totalRx))   \u{2191} \(Format.bytes(snapshot.totalTx))")
                    .foregroundStyle(Theme.body)
            }
            .font(.system(size: 12).monospacedDigit())
        }
        .card()
    }

    private var peak: Double {
        max(downloadHistory.max() ?? 0, uploadHistory.max() ?? 0, 0.001)
    }

    private var uploadColor: Color {
        snapshot.uploadMbps >= AIBrief.saturateMbps ? Theme.load : .primary
    }
}
