import SwiftUI

/// One line of a sparkline.
struct LuckySparkSeries: Identifiable {
    var id: String
    var values: [Double]
    var tone: LuckyTone
    /// Only the primary series is area-filled; two filled series would hide each other.
    var filled: Bool = false
}

/// The rolling chart behind the monitor screen — the last 90 samples of CPU, memory or network
/// speed.
///
/// Series share one vertical scale so in and out speeds stay comparable, and the scale is the
/// maximum across all series rather than per series. The plot is inset to the middle four fifths of
/// the box, with five dashed gridlines behind it, so a reading pinned at 100% still reads as a line
/// instead of merging with the top edge. Drawn in a single `Canvas`: one `Path` per series is far
/// cheaper than a stack of shapes redrawn every second.
struct LuckySparkline: View {
    var series: [LuckySparkSeries]
    var height: CGFloat = 96
    /// Forces the top of the scale, and clamps readings above it. `nil` scales to the largest
    /// sample plus 12% of headroom, so a live line does not ride the ceiling.
    var ceiling: Double?
    /// Samples are taken from the tail, matching `samples.slice(-90)`.
    var window: Int = 90

    /// Gridlines and the plot band live in a 0–1 space over `height`: the original draws a 120-unit
    /// viewBox with lines at 12/36/60/84/108 and plots between 108 and 12.
    private static let gridlines: [CGFloat] = [0.1, 0.3, 0.5, 0.7, 0.9]
    private static let baseline: CGFloat = 0.9
    private static let span: CGFloat = 0.8

    private func peak(in lines: [LuckySparkSeries]) -> Double {
        if let ceiling, ceiling > 0 { return ceiling }
        var highest = 0.0
        for line in lines {
            for value in line.values.suffix(window) where value.isFinite {
                highest = max(highest, value)
            }
        }
        return max(1, highest) * 1.12
    }

    var body: some View {
        let scale = peak(in: series)
        Canvas(rendersAsynchronously: true) { context, size in
            for fraction in Self.gridlines {
                var rule = Path()
                let y = (size.height * fraction).rounded() + 0.5
                rule.move(to: CGPoint(x: 0, y: y))
                rule.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    rule,
                    with: .color(LuckyTheme.separator),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
            }
            for line in series {
                guard let plot = plot(line.values.suffix(window), scale: scale, in: size) else {
                    continue
                }
                if line.filled {
                    let floor = size.height * Self.baseline
                    var area = plot.path
                    area.addLine(to: CGPoint(x: plot.lastX, y: floor))
                    area.addLine(to: CGPoint(x: plot.firstX, y: floor))
                    area.closeSubpath()
                    context.fill(
                        area,
                        with: .linearGradient(
                            Gradient(colors: [line.tone.tint.opacity(0.30),
                                              line.tone.tint.opacity(0.02)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: floor)
                        )
                    )
                }
                context.stroke(
                    plot.path,
                    with: .color(line.tone.tint),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: height)
        .background(ConcentricRectangle().fill(LuckyTheme.surfaceSunken))
        .accessibilityHidden(true)
    }

    private func plot(
        _ values: ArraySlice<Double>,
        scale: Double,
        in size: CGSize
    ) -> (path: Path, firstX: CGFloat, lastX: CGFloat)? {
        guard values.count > 1 else { return nil }
        let step = size.width / CGFloat(values.count - 1)
        var path = Path()
        var firstX: CGFloat = 0
        var lastX: CGFloat = 0
        for (index, raw) in values.enumerated() {
            let value = raw.isFinite ? min(max(raw, 0), scale) : 0
            let y = size.height * (Self.baseline - Self.span * CGFloat(value / scale))
            let point = CGPoint(x: CGFloat(index) * step, y: y)
            if index == 0 {
                firstX = point.x
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            lastX = point.x
        }
        return (path, firstX, lastX)
    }
}
