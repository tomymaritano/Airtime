import DevWifiUI
import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var color: Color = Theme.ok

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * clamped))
            }
        }
        .frame(height: 6)
    }
}
