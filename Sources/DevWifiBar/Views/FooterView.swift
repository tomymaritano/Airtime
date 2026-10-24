import DevWifiCore
import DevWifiUI
import SwiftUI

struct FooterView: View {
    @Binding var launchAtLogin: Bool
    var canManageLogin: Bool
    var onLaunchAtLogin: (Bool) -> Void
    var onWidgets: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Toggle("Open at login", isOn: Binding(
                get: { launchAtLogin },
                set: { onLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 13))
            .disabled(!canManageLogin)
            .help(canManageLogin
                ? "Start \(ProductName.display) when you log in."
                : "Available after installing the .app")

            Spacer()

            Button("Widgets", action: onWidgets)
                .buttonStyle(.bordered)
                .controlSize(.regular)

            Button(action: onQuit) {
                HStack(spacing: 4) {
                    Text("Quit")
                    Text("\u{2318}Q").foregroundStyle(Theme.secondary)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 13))
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}
