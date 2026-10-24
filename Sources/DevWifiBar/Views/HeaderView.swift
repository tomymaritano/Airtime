import DevWifiCore
import SwiftUI

struct HeaderView: View {
    let snapshot: NetworkSnapshot

    var body: some View {
        HStack(alignment: .top) {
            BrandMarkView(offline: !snapshot.wifi.powerOn, color: Theme.teal)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(ProductName.display)
                    .font(.system(size: 15, weight: .semibold))
                Text(updatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.wifi.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                qualityBadge
            }
        }
    }

    private var updatedText: String {
        if snapshot.updatedAt.timeIntervalSince1970 == 0 {
            return "Waiting for sample…"
        }
        return Format.updated(from: snapshot.updatedAt)
    }

    @ViewBuilder
    private var qualityBadge: some View {
        if let quality = snapshot.wifi.quality {
            Text(quality.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(badgeColor(for: quality).opacity(0.18), in: Capsule())
                .foregroundStyle(badgeColor(for: quality))
        } else {
            Text(snapshot.wifi.powerOn ? "No signal" : "Off")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondary)
        }
    }

    private func badgeColor(for quality: SignalQuality) -> Color {
        switch quality {
        case .excellent, .good: return Theme.teal
        case .fair: return .orange
        case .weak, .veryWeak: return .red
        }
    }
}
