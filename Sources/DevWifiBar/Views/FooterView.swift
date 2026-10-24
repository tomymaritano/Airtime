import DevWifiCore
import SwiftUI

struct FooterView: View {
    @Binding var launchAtLogin: Bool
    var canManageLogin: Bool
    var onLaunchAtLogin: (Bool) -> Void
    var onWidgets: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Open at login", isOn: Binding(
                get: { launchAtLogin },
                set: { onLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            .disabled(!canManageLogin)
            .help(canManageLogin
                ? "Start \(ProductName.display) when you log in. AI radar uses process names and destinations only."
                : "Available after installing the .app")

            Spacer()

            Button("Widgets", action: onWidgets)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.teal)

            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
    }
}
