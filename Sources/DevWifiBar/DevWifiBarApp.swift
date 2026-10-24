import AppKit
import SwiftUI

@main
struct DevWifiBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let layout = WidgetLayoutStore()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        state.start()
        statusBar = StatusBarController(state: state, layout: layout)

        if PreviewExport.requested() {
            let docs = PreviewExport.outputDirectory()
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            Task { @MainActor in
                await PreviewExport.run(state: state, layout: layout, directory: docs)
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
