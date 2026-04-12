import SwiftUI

/// Shockwave — each new character sends a circular ripple outward,
/// displacing nearby characters with a subtle wavefront effect.
public struct ShockwaveEffect: StreamingTextEffect {
    public let waveRadius: CGFloat
    public let displacement: CGFloat
    public let trailWidth: Int

    public init(waveRadius: CGFloat = 40, displacement: CGFloat = 3, trailWidth: Int = 8) {
        self.waveRadius = waveRadius
        self.displacement = displacement
        self.trailWidth = trailWidth
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: trailWidth, revealedCount: revealedCount, settledCount: settledCount)

        var cursorPoint: CGPoint?
        var sliceData: [(Int, Text.Layout.RunSlice, CGPoint)] = []

        var globalIndex = 0
        for line in layout {
            for run in line {
                for slice in run {
                    let b = slice.typographicBounds
                    let center = CGPoint(x: b.origin.x + b.width / 2, y: b.origin.y)
                    sliceData.append((globalIndex, slice, center))
                    if globalIndex == revealedCount - 1 {
                        cursorPoint = CGPoint(x: b.origin.x + b.width, y: b.origin.y)
                    }
                    globalIndex += 1
                }
            }
        }

        guard let epicenter = cursorPoint else { return }

        for (index, slice, center) in sliceData {
            guard index < revealedCount else { break }

            let dist = revealedCount - index
            let dx = center.x - epicenter.x
            let dy = center.y - epicenter.y
            let distance = sqrt(dx * dx + dy * dy)

            var offsetX: CGFloat = 0
            var offsetY: CGFloat = 0

            if dist <= trail && distance < waveRadius && distance > 0 {
                let t = Double(dist) / Double(trail)
                let waveFade = max(0, 1.0 - t)
                let distFade = max(0, 1.0 - distance / waveRadius)
                let strength = waveFade * distFade * Double(displacement)

                let normalX = dx / distance
                let normalY = dy / distance
                offsetX = CGFloat(normalX * strength)
                offsetY = CGFloat(normalY * strength)
            }

            var c = ctx
            if offsetX != 0 || offsetY != 0 {
                c.translateBy(x: offsetX, y: offsetY)
            }

            if dist <= 3 {
                let flash = max(0, 1.0 - Double(dist) / 3.0)
                c.drawLayer { layer in
                    layer.opacity = 1.0 + flash * 0.2
                    layer.draw(slice)
                }
            } else {
                c.draw(slice)
            }
        }

        for waveAge in 0..<min(trail, revealedCount) {
            let t = Double(waveAge) / Double(trail)
            let ringRadius = t * Double(waveRadius)
            let opacity = max(0, (1.0 - t) * 0.15)

            if ringRadius > 2 {
                let ringRect = CGRect(
                    x: epicenter.x - ringRadius,
                    y: epicenter.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )
                ctx.drawLayer { layer in
                    layer.stroke(
                        Circle().path(in: ringRect),
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: 1.5
                    )
                    layer.addFilter(.blur(radius: 1))
                }
            }
        }
    }
}
