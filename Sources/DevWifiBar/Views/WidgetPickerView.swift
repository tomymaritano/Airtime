import DevWifiCore
import DevWifiUI
import SwiftUI

/// Chooses which cards show in the panel. The same cards ship as desktop widgets.
struct WidgetPickerView: View {
    @ObservedObject var layout: WidgetLayoutStore
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HStack(spacing: 6) {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .keyboardShortcut(.cancelAction)

                Text("Widgets")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.defaultAction)
            }

            Text("Choose the cards in this panel.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element) { index, widget in
                    row(widget)
                    if index < order.count - 1 {
                        Rectangle().fill(Theme.divider).frame(height: 1)
                    }
                }
            }
            .card(padding: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text("On the desktop")
                    .font(.system(size: 13, weight: .semibold))
                Text("The same cards are desktop and Notification Center widgets: right-click the desktop \u{203A} Edit Widgets \u{203A} \(ProductName.display). macOS refreshes them about every five minutes. On the link fills in after \(ProductName.display) has saved its first snapshot.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.78))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
    }

    private var order: [PanelWidget] {
        [.metric, .signal, .traffic, .combined, .latency, .radar, .network]
    }

    private func row(_ widget: PanelWidget) -> some View {
        Toggle(isOn: Binding(
            get: { layout.isVisible(widget) },
            set: { layout.setVisible(widget, visible: $0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(widget.title)
                    .font(.system(size: 13))
                Text(widget.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Theme.control)
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 9)
    }
}
