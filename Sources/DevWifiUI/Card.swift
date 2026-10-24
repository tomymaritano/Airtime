import SwiftUI

/// Small uppercase card title, e.g. "ON THE LINK".
public struct CardTitle: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Theme.secondary)
    }
}

public struct CardBackground: ViewModifier {
    private let padding: CGFloat

    public init(padding: CGFloat = Theme.cardPadding) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

extension View {
    /// The one container. Cards separate themselves; the panel draws no dividers between them.
    public func card(padding: CGFloat = Theme.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
