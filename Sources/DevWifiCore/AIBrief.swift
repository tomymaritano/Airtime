import Foundation

public struct AIBriefContext: Equatable, Sendable {
    public var quality: SignalQuality?
    public var powerOn: Bool
    public var connected: Bool
    public var latencyMs: Double?
    public var downloadMbps: Double
    public var uploadMbps: Double
    public var downloadRising: Bool
    public var traffic: AITrafficSnapshot
    /// False when the link probe did not exit. Defaults to true so a caller that only has traffic still means "this list is the answer".
    public var probeFinished: Bool

    public init(
        quality: SignalQuality? = nil,
        powerOn: Bool = true,
        connected: Bool = true,
        latencyMs: Double? = nil,
        downloadMbps: Double = 0,
        uploadMbps: Double = 0,
        downloadRising: Bool = false,
        traffic: AITrafficSnapshot = .empty,
        probeFinished: Bool = true
    ) {
        self.quality = quality
        self.powerOn = powerOn
        self.connected = connected
        self.latencyMs = latencyMs
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.downloadRising = downloadRising
        self.traffic = traffic
        self.probeFinished = probeFinished
    }

    public var throughputMbps: Double { downloadMbps + uploadMbps }
}

public enum AIDiagnosisKind: String, Sendable, Equatable, Codable, CaseIterable {
    case offline
    case disconnected
    case unreadable
    case idle
    case live
    case streaming
    case uplinkLag
    case saturated
}

public struct AIEvidence: Equatable, Sendable, Identifiable {
    public var id: String { label }
    public var label: String
    public var value: String
    public var tripped: Bool

    public init(label: String, value: String, tripped: Bool) {
        self.label = label
        self.value = value
        self.tripped = tripped
    }
}

public struct AIDiagnosis: Equatable, Sendable {
    public var kind: AIDiagnosisKind
    public var title: String
    public var reason: String
    public var evidence: [AIEvidence]

    public init(kind: AIDiagnosisKind, title: String, reason: String, evidence: [AIEvidence] = []) {
        self.kind = kind
        self.title = title
        self.reason = reason
        self.evidence = evidence
    }

    public var headline: String { title }

    public static let empty = AIDiagnosis(
        kind: .idle,
        title: "Quiet",
        reason: "No AI apps on the link.",
        evidence: []
    )
}

public enum AIBrief {
    public static let latencyHighMs = 80.0
    public static let latencyClearMs = 60.0
    public static let saturateMbps = 2.5
    public static let saturateClearMbps = 1.6
    public static let streamMbps = 2.0

    public static func diagnose(_ context: AIBriefContext, previous: AIDiagnosisKind? = nil) -> AIDiagnosis {
        let evidence = evidenceRow(context)
        let latency = context.latencyMs ?? 0
        let throughput = context.throughputMbps
        let strongSignal = context.quality == .excellent || context.quality == .good
        let primary = context.traffic.primaryApp ?? "An LLM"

        if !context.powerOn {
            return AIDiagnosis(kind: .offline, title: "Wi-Fi off", reason: "Radar is idle until Wi-Fi is on.", evidence: evidence)
        }
        if !context.connected {
            return AIDiagnosis(kind: .disconnected, title: "Disconnected", reason: "AI apps cannot reach the network.", evidence: evidence)
        }
        // An empty finished reading means nothing matched. A probe that did not exit
        // was killed or never started, and must not be reported as a quiet link.
        if !context.probeFinished {
            return AIDiagnosis(
                kind: .unreadable,
                title: "Couldn't read the link",
                reason: "lsof did not answer, so this is not an empty link.",
                evidence: evidence
            )
        }
        if context.traffic.flows.isEmpty {
            return AIDiagnosis(kind: .idle, title: "Quiet", reason: "No AI apps on the link.", evidence: evidence)
        }

        let holdSaturated = previous == .saturated
            && latency >= latencyClearMs
            && throughput >= saturateClearMbps
            && strongSignal
        let holdUplink = previous == .uplinkLag
            && latency >= latencyClearMs
            && strongSignal

        if (latency >= latencyHighMs && throughput >= saturateMbps && strongSignal) || holdSaturated {
            return AIDiagnosis(
                kind: .saturated,
                title: "Saturated",
                reason: "Ping \(formatMs(context.latencyMs)) is over \(Int(latencyHighMs)) ms and traffic \(Format.mbps(throughput)) is over \(Format.mbps(saturateMbps)). Signal is \(qualityLabel(context.quality)), so Wi-Fi is fine — \(primary) is filling the pipe.",
                evidence: evidence
            )
        }
        if (latency >= latencyHighMs && strongSignal) || holdUplink {
            return AIDiagnosis(
                kind: .uplinkLag,
                title: "Uplink lag",
                reason: "Ping \(formatMs(context.latencyMs)) is over \(Int(latencyHighMs)) ms while signal is \(qualityLabel(context.quality)). The delay is on the path or the LLM host, not RSSI.",
                evidence: evidence
            )
        }
        if context.downloadRising || context.downloadMbps >= streamMbps {
            return AIDiagnosis(
                kind: .streaming,
                title: "Streaming",
                reason: "\(primary) is pulling \(Format.mbps(context.downloadMbps)) down. That is the live load on the link.",
                evidence: evidence
            )
        }
        if context.traffic.flows.count >= 2 {
            return AIDiagnosis(
                kind: .live,
                title: "On the link",
                reason: "\(context.traffic.flows.count) AI apps are connected. Ping \(formatMs(context.latencyMs)), traffic \(Format.mbps(throughput)).",
                evidence: evidence
            )
        }
        return AIDiagnosis(
            kind: .live,
            title: "On the link",
            reason: "\(primary) is connected. Ping \(formatMs(context.latencyMs)), traffic \(Format.mbps(throughput)).",
            evidence: evidence
        )
    }

    public static func isDownloadRising(current: Double, history: [Double]) -> Bool {
        if current >= 5 { return true }
        let prior = Array(history.dropLast().suffix(5))
        guard !prior.isEmpty else { return current >= streamMbps }
        let average = prior.reduce(0, +) / Double(prior.count)
        return current >= streamMbps && current > average * 1.4
    }

    public static func evidenceRow(_ context: AIBriefContext) -> [AIEvidence] {
        let latency = context.latencyMs
        let throughput = context.throughputMbps
        return [
            AIEvidence(
                label: "Ping",
                value: formatMs(latency),
                tripped: (latency ?? 0) >= latencyHighMs
            ),
            AIEvidence(
                label: "Traffic",
                value: Format.mbps(throughput),
                tripped: throughput >= saturateMbps
            ),
            AIEvidence(
                label: "Signal",
                value: qualityLabel(context.quality),
                tripped: false
            ),
        ]
    }

    private static func formatMs(_ value: Double?) -> String {
        Format.latency(value)
    }

    private static func qualityLabel(_ quality: SignalQuality?) -> String {
        quality?.rawValue ?? "—"
    }
}
