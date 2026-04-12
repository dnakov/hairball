import SwiftUI

/// Glow cursor — a colored glow follows the cursor position.
public struct GlowCursorEffect: StreamingTextEffect {
    public let glowColor: Color
    public let glowRadius: CGFloat
    public init(glowColor: Color = .cyan, glowRadius: CGFloat = 8) {
        self.glowColor = glowColor
        self.glowRadius = glowRadius
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        guard let p = drawRevealedAndGetCursorPoint(in: layout, revealedCount: revealedCount, context: &ctx) else { return }

        let glowRect = CGRect(
            x: p.x - glowRadius,
            y: p.y - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        )
        ctx.drawLayer { layer in
            layer.fill(Ellipse().path(in: glowRect), with: .color(glowColor))
            layer.addFilter(.blur(radius: glowRadius * 0.6))
        }
    }
}
