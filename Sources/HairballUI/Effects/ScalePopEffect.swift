import SwiftUI

/// Scale pop — characters scale up as they appear, then settle to normal size.
public struct ScalePopEffect: StreamingTextEffect {
    public let popWidth: Int
    public init(popWidth: Int = 3) { self.popWidth = popWidth }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: popWidth, revealedCount: revealedCount, settledCount: settledCount)
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let distFromCursor = revealedCount - index
            if distFromCursor <= trail {
                let t = Double(distFromCursor) / Double(trail)
                let scale = 1.0 + 0.5 * (1.0 - t)
                let b = slice.typographicBounds
                let cx = b.origin.x + b.width / 2
                let cy = b.origin.y
                var c = context
                c.translateBy(x: cx, y: cy)
                c.scaleBy(x: scale, y: scale)
                c.translateBy(x: -cx, y: -cy)
                c.draw(slice)
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
