import SwiftUI

/// Fire trail — warm gradient glow trailing behind the cursor.
public struct FireTrailEffect: StreamingTextEffect {
    public let trailLength: Int
    public init(trailLength: Int = 15) { self.trailLength = trailLength }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: trailLength, revealedCount: revealedCount, settledCount: settledCount)
        var trailSlices: [(CGPoint, Double)] = []

        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let dist = revealedCount - index
            if dist <= trail {
                let b = slice.typographicBounds
                let t = Double(dist) / Double(trail)
                trailSlices.append((CGPoint(x: b.origin.x + b.width / 2, y: b.origin.y), t))
                context.drawLayer { layer in
                    let warmth = max(0, 1.0 - t)
                    layer.addFilter(.colorMultiply(Color(
                        red: 1.0,
                        green: 0.5 + warmth * 0.5,
                        blue: warmth * 0.3
                    )))
                    layer.draw(slice)
                }
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)

        ctx.drawLayer { layer in
            for (point, t) in trailSlices {
                let size = (1.0 - t) * 8
                let opacity = (1.0 - t) * 0.7
                let yJitter = sin(t * Double(trail) * 1.5) * 3
                let rect = CGRect(
                    x: point.x - size/2,
                    y: point.y - size/2 + yJitter - 4,
                    width: size, height: size
                )
                layer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: 1.0, green: 0.4 * t, blue: 0.0).opacity(opacity))
                )
            }
            layer.addFilter(.blur(radius: 3))
        }
    }
}
