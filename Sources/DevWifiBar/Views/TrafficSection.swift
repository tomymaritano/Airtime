import DevWifiCore
import DevWifiUI
import SwiftUI

struct TrafficSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            SparklineView(values: downloadHistory, color: Theme.down)
                .frame(height: 28)

            HStack {
                Label(Format.mbps(snapshot.downloadMbps), systemImage: "arrow.down")
                Spacer()
                Label(Format.mbps(snapshot.uploadMbps), systemImage: "arrow.up")
            }
            .font(.system(size: 11).monospacedDigit())
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.primary)

            HStack {
                Text("RX \(Format.bytes(snapshot.totalRx))")
                Spacer()
                Text("TX \(Format.bytes(snapshot.totalTx))")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondary)
        }
    }
}
