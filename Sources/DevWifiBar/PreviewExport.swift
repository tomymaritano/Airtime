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

        // The widget `Widget` conformances (StaticConfiguration, kind,
        // supportedFamilies) live in Sources/DevWifiBarWidgets, a separate target
        // the app cannot import. Their views, however, live in DevWifiUI, which
        // both targets import — so these are the real widget views, not copies.
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

        exportWidget("widget-signal.png", size: small) { SignalWidgetView(snapshot: snapshot) }
        exportWidget("widget-metric.png", size: small) { MetricWidgetView(snapshot: snapshot) }
        exportWidget("widget-latency.png", size: small) { LatencyWidgetView(snapshot: snapshot) }
        exportWidget("widget-traffic.png", size: medium) { TrafficWidgetView(snapshot: snapshot, isCompact: false) }
        exportWidget("widget-network.png", size: medium) { NetworkWidgetView(snapshot: snapshot) }
        exportWidget("widget-radar.png", size: medium) { RadarWidgetView(snapshot: snapshot) }
        exportWidget("widget-combined.png", size: medium) { CombinedWidgetView(snapshot: snapshot) }

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
    ///
    /// Known limitation: `.borderedProminent` buttons (e.g. the Location
    /// banner's "Allow…") rasterise unemphasized/grey here instead of blue.
    /// A `canBecomeKey`/`canBecomeMain` window subclass, `makeKeyAndOrderFront`,
    /// app activation, placing the window on-screen, and delaying the render
    /// were all tried to make this window key and were reverted — none made
    /// the button render emphasized. The live app shows it correctly.
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
