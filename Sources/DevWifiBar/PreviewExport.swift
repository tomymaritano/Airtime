import AppKit
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

        let panel = MenuPanelView()
            .environmentObject(state)
            .environmentObject(layout)
        write(panel, to: directory.appendingPathComponent("panel.png"), scale: 2)

        let mark = BrandMarkView(color: .white)
            .frame(width: 128, height: 128)
            .padding(24)
            .background(Theme.background)
        write(mark, to: directory.appendingPathComponent("mark.png"), scale: 2)
    }

    private static func write<V: View>(_ view: V, to url: URL, scale: CGFloat) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage else { return }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}
