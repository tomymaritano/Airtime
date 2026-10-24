import DevWifiCore
import SwiftUI

/// The seven widget surfaces, shared between the widget extension
/// (`DevWifiBarWidgets`, which wraps each in a `Widget` conformance with its
/// `StaticConfiguration`, `kind`, and `supportedFamilies`) and the app's
/// documentation screenshot export (`PreviewExport`), which renders these
/// exact views instead of hand-maintaining lookalikes.
///
/// These are pure SwiftUI over `WidgetSnapshot` and `Theme` — nothing here
/// needs the extension's framework, so this file stays safe for the
/// `APPLICATION_EXTENSION_API_ONLY` extension target as well as the main app target.

public struct SignalWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "Signal", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                Text(snapshot.signalQuality?.rawValue ?? (snapshot.powerOn ? "No signal" : "Wi-Fi off"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                SignalMeter(
                    filled: snapshot.signalQuality?.segments ?? 0,
                    color: Theme.color(for: snapshot.signalQuality)
                )

                HStack(alignment: .top) {
                    detail("Channel", snapshot.channel.map { $0 > 0 ? "\($0)" : "\u{2014}" } ?? "\u{2014}")
                    detail("RSSI", Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 12).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct MetricWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "Metric", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct LatencyWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "Latency", trailing: "1.1.1.1", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Format.latency(snapshot.latencyMs))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))

                SparklineView(
                    values: snapshot.latencyHistory,
                    color: Theme.color(forLatency: snapshot.latencyMs),
                    peak: max(snapshot.latencyHistory.max() ?? 0, 60)
                )
                .frame(height: 28)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }
}

/// `isCompact` stands in for the widget family: `true` for `.systemSmall`'s
/// shorter chart, `false` for `.systemMedium`'s taller one. This view has no
/// notion of widget families — only of how much room it has — so the caller
/// (the real `TrafficWidget`, or the docs export) decides.
public struct TrafficWidgetView: View {
    let snapshot: WidgetSnapshot
    public var isCompact: Bool

    public init(snapshot: WidgetSnapshot, isCompact: Bool) {
        self.snapshot = snapshot
        self.isCompact = isCompact
    }

    public var body: some View {
        WidgetCard(title: "Traffic", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(uploadColor)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .lineLimit(1)

                ZStack {
                    SparklineView(values: snapshot.downloadHistory, color: Theme.down, peak: peak)
                    SparklineView(values: snapshot.uploadHistory, color: Theme.load, peak: peak)
                }
                .frame(height: isCompact ? 26 : 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }

    private var peak: Double {
        max(snapshot.downloadHistory.max() ?? 0, snapshot.uploadHistory.max() ?? 0, AIBrief.saturateMbps)
    }

    private var uploadColor: Color {
        Theme.color(forUpload: snapshot.uploadMbps)
    }
}

public struct NetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "Network", trailing: snapshot.displayName, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 7) {
                row("IP address", snapshot.localIP.isEmpty ? "\u{2014}" : snapshot.localIP)
                row("Gateway", snapshot.gateway.isEmpty ? "\u{2014}" : snapshot.gateway)
                row("DNS", snapshot.dns.isEmpty ? "\u{2014}" : snapshot.dns)
                row("Latency to 1.1.1.1", Format.latency(snapshot.latencyMs))
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
        }
    }
}

public struct RadarWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "On the link", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.diagnosisKind))
                    Text(snapshot.diagnosisTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color(for: snapshot.diagnosisKind))
                }

                Text(snapshot.diagnosisReason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.body)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let app = snapshot.topApp {
                    Text(app)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct CombinedWidgetView: View {
    let snapshot: WidgetSnapshot

    public init(snapshot: WidgetSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetCard(title: "Combined", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.signalQuality))
                    Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    Spacer(minLength: 4)
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(Theme.color(forUpload: snapshot.uploadMbps))
                    Spacer(minLength: 4)
                    Text(Format.latency(snapshot.latencyMs))
                        .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .lineLimit(1)

                SparklineView(
                    values: snapshot.downloadHistory,
                    color: Theme.down,
                    peak: max(snapshot.downloadHistory.max() ?? 0, AIBrief.saturateMbps)
                )
                    .frame(height: 30)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.divider).frame(height: 1)
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
