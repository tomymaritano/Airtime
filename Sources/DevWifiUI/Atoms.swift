import SwiftUI

/// 8pt dot that carries a semantic colour beside a label.
public struct StatusDot: View {
    private let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

/// A chip is either neutral or carries a semantic colour. Modelled explicitly
/// rather than by comparing a `Color` to `.primary`, which hides the intent.
public enum ChipTint {
    case neutral
    case semantic(Color)

    var foreground: Color {
        switch self {
        case .neutral: return .primary
        case .semantic(let color): return color
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Color.white.opacity(0.06)
        case .semantic(let color): return color.opacity(0.15)
        }
    }
}

/// Label over a large monospaced value, e.g. "Ping" / "120 ms".
public struct EvidenceChip: View {
    private let label: String
    private let value: String
    private let tint: ChipTint

    public init(label: String, value: String, tint: ChipTint) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.78))
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Row that lights on hover and deepens on press. Panel only — widgets are not interactive.
public struct RowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HoverRow(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct HoverRow<Label: View>: View {
    let label: Label
    let pressed: Bool
    @State private var hovering = false

    var body: some View {
        label
            .background(
                Color.white.opacity(pressed ? 0.10 : (hovering ? 0.05 : 0)),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .onHover { hovering = $0 }
    }
}
