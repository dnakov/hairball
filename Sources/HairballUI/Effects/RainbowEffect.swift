import SwiftUI

/// Rainbow — characters cycle through hue colors near the cursor.
public struct RainbowEffect: StreamingTextEffect {
    public let trailLength: Int
    public init(trailLength: Int = 12) { self.trailLength = trailLength }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: trailLength, revealedCount: revealedCount, settledCount: settledCount)
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let dist = revealedCount - index
            if dist <= trail {
                let hue = Double(index % 12) / 12.0
                context.drawLayer { layer in
                    layer.addFilter(.colorMultiply(Color(hue: hue, saturation: 0.8, brightness: 1.0)))
                    layer.draw(slice)
                }
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
