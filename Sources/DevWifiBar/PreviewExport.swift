import AppKit
import DevWifiCore
import DevWifiUI
import SwiftUI

@MainActor
enum PreviewExport {
    static func requested(from arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.contains("--export-docs")
    }

    static func outputDirectory(from arguments: [String] = CommandLine.arguments) -> URL {
        if let index = arguments.firstIndex(of: "--export-docs"),
           arguments.indices.contains(index + 1),
           !arguments[index + 1].hasPrefix("-") {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/media", isDirectory: true)
    }

    static func run(state: AppState, layout: WidgetLayoutStore, directory: URL) async {
        try? await Task.sleep(for: .seconds(5))

        var failures: [String] = []
        var successCount = 0

        func export<V: View>(_ name: String, _ view: V) {
            let url = directory.appendingPathComponent(name)
            if write(view, to: url, scale: 2) {
                successCount += 1
            } else {
                failures.append(name)
            }
        }

        let panel = MenuPanelView()
            .environmentObject(state)
            .environmentObject(layout)
        export("panel.png", panel)

        let mark = BrandMarkView(color: .white)
            .frame(width: 128, height: 128)
            .padding(24)
            .background(Theme.background)
        export("mark.png", mark)

        // The widget views live in Sources/DevWifiBarWidgets, a separate target the
        // app cannot import, so their bodies are reproduced here using the same
        // DevWifiCore/DevWifiUI primitives (Theme, Format, SparklineView, etc.) that
        // the real widgets use. No app- or widget-specific business logic is
        // duplicated — only the SwiftUI layout glue that arranges those primitives.
        let snapshot = WidgetSnapshot.make(
            snapshot: state.snapshot,
            downloadHistory: state.downloadHistory,
            uploadHistory: state.uploadHistory,
            latencyHistory: state.latencyHistory,
            diagnosis: state.aiDiagnosis,
            topFlow: state.aiTraffic.topFlows.first
        )

        let small = CGSize(width: 170, height: 170)
        let medium = CGSize(width: 364, height: 170)

        func exportWidget<V: View>(_ name: String, size: CGSize, @ViewBuilder _ content: () -> V) {
            let framed = content()
                .frame(width: size.width, height: size.height)
                .background(Theme.background)
            export(name, framed)
        }

        exportWidget("widget-signal.png", size: small) { DocsSignalWidgetView(snapshot: snapshot) }
        exportWidget("widget-metric.png", size: small) { DocsMetricWidgetView(snapshot: snapshot) }
        exportWidget("widget-latency.png", size: small) { DocsLatencyWidgetView(snapshot: snapshot) }
        exportWidget("widget-traffic.png", size: medium) { DocsTrafficWidgetView(snapshot: snapshot) }
        exportWidget("widget-network.png", size: medium) { DocsNetworkWidgetView(snapshot: snapshot) }
        exportWidget("widget-radar.png", size: medium) { DocsRadarWidgetView(snapshot: snapshot) }
        exportWidget("widget-combined.png", size: medium) { DocsCombinedWidgetView(snapshot: snapshot) }

        if failures.isEmpty {
            print("PreviewExport: wrote \(successCount) PNG(s) to \(directory.path)")
        } else {
            print(
                "PreviewExport: FAILED to render \(failures.count) of \(successCount + failures.count) file(s): "
                    + failures.joined(separator: ", ")
            )
        }
    }

    /// Hosts `view` in a real (off-screen) window and rasterises it there, rather
    /// than with `ImageRenderer`, which cannot draw AppKit-backed controls such as
    /// `Toggle(.checkbox)` or bordered/borderless `Button`s — it leaves placeholder
    /// glyphs where they belong. A real `NSWindow` + `NSHostingView` lays those
    /// controls out and draws them like the running app does.
    ///
    /// Returns `false` (and leaves no file behind) on any failure, so a broken
    /// render cannot look like a successful export.
    @discardableResult
    private static func write<V: View>(_ view: V, to url: URL, scale: CGFloat) -> Bool {
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        guard size.width > 0, size.height > 0 else {
            print("PreviewExport: \(url.lastPathComponent) failed - view has zero fitting size")
            return false
        }
        hosting.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.appearance = NSAppearance(named: .darkAqua)
        // Off-screen but real, so AppKit controls lay out and draw correctly.
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        defer { window.orderOut(nil) }

        // `bitmapImageRepForCachingDisplay` would follow the window's backing
        // scale, which an off-screen window not placed on any real display cannot
        // be relied on to report as 2x. Build the bitmap explicitly at `scale`x
        // the point size instead: setting `rep.size` to the point size while the
        // pixel dimensions are doubled tells `cacheDisplay` to render at that
        // higher resolution regardless of screen.
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              )
        else {
            print("PreviewExport: \(url.lastPathComponent) failed - could not allocate a bitmap rep")
            return false
        }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("PreviewExport: \(url.lastPathComponent) failed - could not encode PNG data")
            return false
        }
        do {
            try png.write(to: url)
        } catch {
            print("PreviewExport: \(url.lastPathComponent) failed - could not write file: \(error)")
            return false
        }
        return true
    }
}

// MARK: - Widget view reproductions for documentation screenshots
//
// Sources/DevWifiBarWidgets is a separate target that this app target cannot
// import, so each `*WidgetView`'s body is reproduced here against the shared
// DevWifiCore/DevWifiUI primitives the real widgets use. Keep these in sync
// with Sources/DevWifiBarWidgets/*Widget.swift if those layouts change.

/// Stand-in for `DevWifiBarWidgets.WidgetCard`.
private struct DocsWidgetCard<Content: View>: View {
    let title: String
    var trailing: String?
    var offline: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                BrandMarkView(offline: offline, color: .primary)
                    .frame(width: 14, height: 14)
                CardTitle(text: title)
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
            content()
        }
        .padding(Theme.widgetPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }
}

private struct DocsSignalWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Signal", offline: !snapshot.powerOn) {
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

private struct DocsMetricWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Metric", offline: !snapshot.powerOn) {
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

private struct DocsLatencyWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Latency", trailing: "1.1.1.1", offline: !snapshot.powerOn) {
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

private struct DocsTrafficWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Traffic", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(Theme.color(forUpload: snapshot.uploadMbps))
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .lineLimit(1)

                ZStack {
                    SparklineView(values: snapshot.downloadHistory, color: Theme.down, peak: peak)
                    SparklineView(values: snapshot.uploadHistory, color: Theme.load, peak: peak)
                }
                .frame(height: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }

    private var peak: Double {
        max(snapshot.downloadHistory.max() ?? 0, snapshot.uploadHistory.max() ?? 0, AIBrief.saturateMbps)
    }
}

private struct DocsNetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Network", trailing: snapshot.displayName, offline: !snapshot.powerOn) {
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

private struct DocsRadarWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "On the link", offline: !snapshot.powerOn) {
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

private struct DocsCombinedWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        DocsWidgetCard(title: "Combined", offline: !snapshot.powerOn) {
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
