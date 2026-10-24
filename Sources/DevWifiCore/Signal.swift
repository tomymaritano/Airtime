/// Wi-Fi signal quality thresholds, matching the `devwifi` CLI.
public enum SignalQuality: String, Sendable, Equatable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    case veryWeak = "Very Weak"

    /// Classify an RSSI value in dBm using the same cutoffs as `devwifi`.
    public static func from(dbm: Int) -> SignalQuality {
        if dbm >= -50 { return .excellent }
        if dbm >= -60 { return .good }
        if dbm >= -70 { return .fair }
        if dbm >= -80 { return .weak }
        return .veryWeak
    }
}

extension SignalQuality {
    /// Lit segments in the five-step meter.
    public var segments: Int {
        switch self {
        case .excellent: return 5
        case .good: return 4
        case .fair: return 3
        case .weak: return 2
        case .veryWeak: return 1
        }
    }
}

/// Map RSSI to 0...1. −30 dBm is 100%, −90 dBm is 0%.
public func rssiToPercent(_ dbm: Int) -> Double {
    let clamped = min(max(dbm, -90), -30)
    return Double(clamped + 90) / 60.0
}
