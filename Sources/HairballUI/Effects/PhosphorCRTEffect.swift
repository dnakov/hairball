import SwiftUI

/// Phosphor CRT — old green-screen terminal effect. Characters appear bright white,
/// then decay through bright green → dim green with a soft blur glow. Includes scanlines.
public struct PhosphorCRTEffect: StreamingTextEffect {
    public let decayLength: Int
    public init(decayLength: Int = 20) { self.decayLength = decayLength }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: decayLength, revealedCount: revealedCount, settledCount: settledCount)

        // Accumulate scanline bounds during the draw pass
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude

        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }

            let b = slice.typographicBounds
            minY = min(minY, b.origin.y - b.ascent)
            maxY = max(maxY, b.origin.y + b.descent)
            minX = min(minX, b.origin.x)
            maxX = max(maxX, b.origin.x + b.width)

            let dist = revealedCount - index

            if dist <= trail {
                let t = Double(dist) / Double(trail)
                let red = max(0, 1.0 - t * 3.0)
                let green = max(0.2, 1.0 - t * 0.6)
                let blue = max(0, 0.8 - t * 2.0)
                let glow = max(0, 1.0 - t * 0.8)

                context.drawLayer { layer in
                    layer.addFilter(.colorMultiply(Color(red: red, green: green, blue: blue)))
                    layer.draw(slice)
                }

                if dist <= 5 {
                    let bloomOpacity = (1.0 - Double(dist) / 5.0) * 0.4
                    context.drawLayer { layer in
                        layer.opacity = bloomOpacity
                        layer.addFilter(.colorMultiply(Color(red: 0.5 + glow * 0.5, green: 1.0, blue: 0.5)))
                        layer.addFilter(.blur(radius: 4))
                        layer.draw(slice)
                    }
                }
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)

        // Scanlines
        guard minY < maxY else { return }

        ctx.drawLayer { layer in
            var y = minY
            while y < maxY {
                layer.fill(
                    Path(CGRect(x: minX, y: y, width: maxX - minX, height: 1)),
                    with: .color(Color.black.opacity(0.12))
                )
                y += 3
            }
        }
    }
}
