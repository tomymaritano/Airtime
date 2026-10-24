import SwiftUI

/// Wi-Fi fan on a bar — the Airtime mark.
public struct BrandMarkView: View {
    private let offline: Bool
    private let color: Color

    public init(offline: Bool = false, color: Color = .primary) {
        self.offline = offline
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.10)
            let w = rect.width
            let h = rect.height
            let origin = CGPoint(x: rect.midX, y: rect.maxY - h * 0.22)
            let ink = color.opacity(offline ? 0.35 : 1)

            let bar = CGRect(x: rect.minX + w * 0.12, y: rect.maxY - h * 0.16, width: w * 0.76, height: h * 0.13)
            context.fill(Path(roundedRect: bar, cornerRadius: bar.height / 2), with: .color(ink))

            let stroke = max(1.7, w * 0.13)
            for radius in [w * 0.22, w * 0.40, w * 0.58] {
                var arc = Path()
                arc.addArc(center: origin, radius: radius, startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
