import SwiftUI

/// Fade edge — revealed text is solid, last N characters fade out.
public struct FadeEdgeEffect: StreamingTextEffect {
    public let edgeWidth: Int
    public init(edgeWidth: Int = 4) { self.edgeWidth = edgeWidth }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: edgeWidth, revealedCount: revealedCount, settledCount: settledCount)
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let distFromCursor = revealedCount - index
            if distFromCursor <= trail {
                var c = context
                c.opacity = Double(distFromCursor) / Double(trail)
                c.draw(slice)
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
