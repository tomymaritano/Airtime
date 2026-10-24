import SwiftUI

/// Line sparkline. Pass `peak` to put several series on one scale.
public struct SparklineView: View {
    private let values: [Double]
    private let color: Color
    private let peak: Double?
    private let lineWidth: CGFloat

    public init(values: [Double], color: Color = Theme.down, peak: Double? = nil, lineWidth: CGFloat = 2) {
        self.values = values
        self.color = color
        self.peak = peak
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            if values.count < 2 {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: geo.size.width, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            } else {
                SparklinePath(values: values, peak: max(peak ?? values.max() ?? 0, 0.001))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SparklinePath: Shape {
    let values: [Double]
    let peak: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.insetBy(dx: 1, dy: 2)
        let step = inset.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let ratio = CGFloat(min(max(value / peak, 0), 1))
            let point = CGPoint(x: inset.minX + CGFloat(index) * step, y: inset.maxY - ratio * inset.height)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Five segments, one per signal quality step.
public struct SignalMeter: View {
    private let filled: Int
    private let color: Color

    public init(filled: Int, color: Color) {
        self.filled = filled
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? color : Color.white.opacity(0.10))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Proportional bar. `share` is already clamped by the caller.
public struct ShareBar: View {
    private let share: Double
    private let color: Color

    public init(share: Double, color: Color) {
        self.share = share
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color).frame(width: geo.size.width * share)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
