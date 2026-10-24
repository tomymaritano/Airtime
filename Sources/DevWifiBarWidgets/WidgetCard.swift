import DevWifiUI
import SwiftUI

/// A widget's whole surface is one card: mark, title, optional trailing label,
/// then content. The dark background comes from `containerBackground` in each
/// widget's configuration.
struct WidgetCard<Content: View>: View {
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
