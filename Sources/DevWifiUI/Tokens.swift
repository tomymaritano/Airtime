import DevWifiCore
import SwiftUI

/// Panel and widget tokens. Dark macOS system colours, so values read the same
/// as the rest of the menu bar. Airtime is dark everywhere: these are literal
/// hex on purpose, not `Color(nsColor:)` system colours that resolve per
/// appearance.
public enum Theme {
    // Surfaces
    public static let background = Color(red: 0.110, green: 0.110, blue: 0.118) // #1C1C1E
    public static let card = Color(red: 0.165, green: 0.165, blue: 0.176)       // #2A2A2D
    public static let divider = Color.white.opacity(0.08)
    public static let hairline = Color.white.opacity(0.12)

    // Text
    public static let body = Color(red: 0.820, green: 0.820, blue: 0.839)       // #D1D1D6
    public static let secondary = Color(red: 0.596, green: 0.596, blue: 0.624)  // #98989F

    // Semantics. Colour means "look at this"; its absence is also a signal.
    /// Ping or traffic over the line, and the Saturated / Uplink lag verdicts.
    public static let load = Color(red: 1.0, green: 0.624, blue: 0.039)         // #FF9F0A
    /// Healthy signal, low ping, Quiet.
    public static let ok = Color(red: 0.188, green: 0.820, blue: 0.345)         // #30D158
    /// Download series and links.
    public static let down = Color(red: 0.416, green: 0.706, blue: 1.0)         // #6AB4FF
    /// Weak and very weak signal.
    public static let bad = Color(red: 1.0, green: 0.412, blue: 0.380)          // #FF6961
    /// Controls that are on.
    public static let control = Color(red: 0.039, green: 0.392, blue: 0.847)    // #0A64D8

    // Metrics
    public static let panelWidth: CGFloat = 360
    public static let panelPadding: CGFloat = 12
    public static let cardSpacing: CGFloat = 8
    public static let cardPadding: CGFloat = 12
    public static let cardRadius: CGFloat = 10
    /// Widgets own their container, which is roomier than a panel card.
    public static let widgetPadding: CGFloat = 14

    /// Fair returns `.primary`: it is neither good nor bad, and the absence of
    /// colour is the signal.
    public static func color(for quality: SignalQuality?) -> Color {
        switch quality {
        case .excellent, .good: return ok
        case .fair: return .primary
        case .weak: return load
        case .veryWeak: return bad
        case nil: return secondary
        }
    }

    public static func color(forLatency ms: Double?) -> Color {
        guard let ms else { return secondary }
        return ms >= AIBrief.latencyHighMs ? load : ok
    }

    public static func color(for kind: AIDiagnosisKind) -> Color {
        switch kind {
        case .saturated, .uplinkLag: return load
        case .streaming, .live: return down
        case .idle: return ok
        case .unreadable, .offline, .disconnected: return secondary
        }
    }
}
