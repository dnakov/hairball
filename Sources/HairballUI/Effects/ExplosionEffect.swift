import SwiftUI

/// Explosion — each character bursts in with expanding particle ring.
public struct ExplosionEffect: StreamingTextEffect {
    public let burstRadius: CGFloat
    public let particleCount: Int
    public let trailWidth: Int

    public init(burstRadius: CGFloat = 14, particleCount: Int = 10, trailWidth: Int = 6) {
        self.burstRadius = burstRadius
        self.particleCount = particleCount
        self.trailWidth = trailWidth
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: trailWidth, revealedCount: revealedCount, settledCount: settledCount)
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let dist = revealedCount - index

            if dist <= trail {
                let t = Double(dist) / Double(trail)
                let shake = (1.0 - t) * 2.0
                let shakeX = sin(Double(index) * 7.0) * shake
                let shakeY = cos(Double(index) * 11.0) * shake

                var c = context
                c.translateBy(x: shakeX, y: shakeY)

                if dist <= 2 {
                    c.drawLayer { layer in
                        layer.addFilter(.colorMultiply(.white))
                        layer.draw(slice)
                    }
                } else {
                    c.draw(slice)
                }

                let b = slice.typographicBounds
                let cx = b.origin.x + b.width / 2
                let cy = b.origin.y

                let expansion = t
                let opacity = max(0, 1.0 - t * 1.2)

                context.drawLayer { layer in
                    for i in 0..<particleCount {
                        let angle = (Double(i) / Double(particleCount)) * .pi * 2
                        let jitter = Double((index * 13 + i * 7) % 100) / 100.0
                        let r = expansion * Double(burstRadius) * (0.6 + jitter * 0.4)
                        let px = cx + cos(angle + jitter) * r
                        let py = cy + sin(angle + jitter) * r
                        let size = (1.0 - t) * 3.0 + 0.5

                        let hue = Double((index + i) % 8) / 8.0
                        layer.fill(
                            Circle().path(in: CGRect(x: px - size/2, y: py - size/2, width: size, height: size)),
                            with: .color(Color(hue: hue, saturation: 0.9, brightness: 1.0).opacity(opacity))
                        )
                    }
                    layer.addFilter(.blur(radius: 1.0))
                }
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
