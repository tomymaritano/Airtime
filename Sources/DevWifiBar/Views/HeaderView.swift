import AppKit
import DevWifiCore
import DevWifiUI
import SwiftUI

@MainActor
struct HeaderView: View {
    let snapshot: NetworkSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HStack(alignment: .center, spacing: 10) {
                BrandMarkView(offline: !snapshot.wifi.powerOn, color: .primary)
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.wifi.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(detailLine)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(updatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            if needsLocation {
                LocationBanner()
            }
        }
    }

    private var detailLine: String {
        guard snapshot.wifi.powerOn else { return "Wi-Fi is off" }
        guard snapshot.wifi.connected else { return "Not connected" }
        var parts: [String] = []
        if let quality = snapshot.wifi.quality { parts.append(quality.rawValue) }
        if let rssi = snapshot.wifi.rssi { parts.append(Format.rssi(rssi).replacingOccurrences(of: "-", with: "\u{2212}")) }
        if let channel = snapshot.wifi.channel, channel > 0 { parts.append("ch \(channel)") }
        return parts.isEmpty ? "No signal" : parts.joined(separator: " \u{00B7} ")
    }

    private var updatedText: String {
        if snapshot.updatedAt.timeIntervalSince1970 == 0 {
            return "Waiting\u{2026}"
        }
        return Format.updated(from: snapshot.updatedAt).replacingOccurrences(of: "Updated ", with: "")
    }

    /// Without Location the SSID is hidden; everything else still works.
    private var needsLocation: Bool {
        snapshot.wifi.connected && snapshot.wifi.ssid == nil && !LocationGate.shared.isAuthorized
    }
}

/// App-only: opens System Settings. This is why the banner cannot live in DevWifiUI.
@MainActor
private struct LocationBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Allow Location to show the network name. Everything else works without it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Allow\u{2026}") {
                LocationGate.shared.requestIfNeeded()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.down.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}
