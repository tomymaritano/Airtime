import AppKit
import DevWifiCore
import SwiftUI

/// Wi-Fi fan on a bar — the DevWifiBar mark. Template so it matches the menu bar.
enum BrandMark {
    static let menuBarPointSize: CGFloat = 18

    static func menuBarImage(for snapshot: NetworkSnapshot) -> NSImage {
        let size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
        let image = NSImage(size: size, flipped: true) { rect in
            let alpha: CGFloat = snapshot.wifi.powerOn ? 1 : 0.35
            NSColor.black.withAlphaComponent(alpha).setFill()
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func draw(in rect: CGRect) {
        let inset = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.10)
        let w = inset.width
        let h = inset.height
        let origin = CGPoint(x: inset.midX, y: inset.maxY - h * 0.22)

        // Baseline — the "bar"
        let bar = CGRect(x: inset.minX + w * 0.12, y: inset.maxY - h * 0.16, width: w * 0.76, height: h * 0.13)
        NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()

        // Wifi arcs rising from the bar
        let stroke = max(1.7, w * 0.13)
        for (index, radius) in [w * 0.22, w * 0.40, w * 0.58].enumerated() {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: origin, radius: radius, startAngle: 210, endAngle: 330)
            arc.lineWidth = stroke - CGFloat(index) * 0.08
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
        }
    }
}

struct BrandMarkView: View {
    var offline: Bool = false
    var color: Color = .primary

    var body: some View {
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
