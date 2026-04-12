import SwiftUI

/// Sparkle trail — particles burst from the cursor position.
public struct SparkleEffect: StreamingTextEffect {
    public let sparkleCount: Int
    public let color: Color
    public init(sparkleCount: Int = 6, color: Color = .yellow) {
        self.sparkleCount = sparkleCount
        self.color = color
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        guard let p = drawRevealedAndGetCursorPoint(in: layout, revealedCount: revealedCount, context: &ctx) else { return }

        ctx.drawLayer { layer in
            for i in 0..<sparkleCount {
                let angle = Double(i) / Double(sparkleCount) * .pi * 2
                let seed = Double((revealedCount * 7 + i * 13) % 100) / 100.0
                let dist = 4.0 + seed * 12.0
                let x = p.x + cos(angle + seed * 2) * dist
                let y = p.y + sin(angle + seed * 2) * dist
                let size = 1.5 + seed * 2.5
                let opacity = max(0, 1.0 - seed * 0.6)
                layer.fill(
                    Circle().path(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size)),
                    with: .color(color.opacity(opacity))
                )
            }
            layer.addFilter(.blur(radius: 1.5))
        }
    }
}
