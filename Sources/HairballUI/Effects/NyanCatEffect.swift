import SwiftUI

/// Nyan Cat — pixel-art cat with rainbow trail follows the cursor.
public struct NyanCatEffect: StreamingTextEffect {
    public init() {}

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        guard let p = drawRevealedAndGetCursorPoint(in: layout, revealedCount: revealedCount, context: &ctx) else { return }

        let px: CGFloat = 2.0
        let catX = p.x + 4
        let catY = p.y - 6

        let rainbowColors: [Color] = [
            Color(red: 1.0, green: 0.0, blue: 0.0),
            Color(red: 1.0, green: 0.6, blue: 0.0),
            Color(red: 1.0, green: 1.0, blue: 0.0),
            Color(red: 0.0, green: 0.8, blue: 0.0),
            Color(red: 0.0, green: 0.6, blue: 1.0),
            Color(red: 0.6, green: 0.3, blue: 1.0),
        ]

        let trailLength: CGFloat = 30
        let stripeHeight = px * 1.2
        let bounce = sin(Double(revealedCount) * 0.5) * 2

        ctx.drawLayer { layer in
            for (i, color) in rainbowColors.enumerated() {
                let y = catY + CGFloat(i + 1) * stripeHeight - 2 + CGFloat(bounce)
                layer.fill(
                    Path(CGRect(x: catX - trailLength, y: y, width: trailLength, height: stripeHeight)),
                    with: .color(color.opacity(0.9))
                )
            }
        }

        let tartX = catX - px
        let tartY = catY + CGFloat(bounce)
        ctx.drawLayer { layer in
            layer.fill(
                RoundedRectangle(cornerRadius: 2).path(in: CGRect(
                    x: tartX, y: tartY, width: px * 6, height: px * 5
                )),
                with: .color(Color(red: 0.85, green: 0.75, blue: 0.55))
            )
            layer.fill(
                RoundedRectangle(cornerRadius: 1).path(in: CGRect(
                    x: tartX + px * 0.5, y: tartY + px * 0.5, width: px * 5, height: px * 3.5
                )),
                with: .color(Color(red: 1.0, green: 0.6, blue: 0.7))
            )
            let sprinkles: [(CGFloat, CGFloat)] = [(1.5, 1.5), (3.5, 1), (2, 3), (4, 2.5)]
            for (sx, sy) in sprinkles {
                layer.fill(
                    Circle().path(in: CGRect(
                        x: tartX + sx * px, y: tartY + sy * px, width: px * 0.6, height: px * 0.6
                    )),
                    with: .color(Color(red: 1.0, green: 0.3, blue: 0.5))
                )
            }
        }

        ctx.drawLayer { layer in
            let headX = catX + px * 5
            let headY = tartY - px * 0.5
            layer.fill(
                RoundedRectangle(cornerRadius: 1.5).path(in: CGRect(
                    x: headX, y: headY, width: px * 4, height: px * 4
                )),
                with: .color(Color(red: 0.6, green: 0.6, blue: 0.6))
            )
            for ex: CGFloat in [0.3, 2.7] {
                layer.fill(
                    Path { path in
                        path.move(to: CGPoint(x: headX + ex * px, y: headY))
                        path.addLine(to: CGPoint(x: headX + (ex + 0.7) * px, y: headY - px * 1.2))
                        path.addLine(to: CGPoint(x: headX + (ex + 1.4) * px, y: headY))
                        path.closeSubpath()
                    },
                    with: .color(Color(red: 0.6, green: 0.6, blue: 0.6))
                )
            }
            for ex: CGFloat in [0.8, 2.4] {
                layer.fill(
                    Circle().path(in: CGRect(
                        x: headX + ex * px, y: headY + px * 1.2, width: px * 0.8, height: px * 0.8
                    )),
                    with: .color(.black)
                )
            }
            layer.fill(
                Ellipse().path(in: CGRect(
                    x: headX + px * 1.2, y: headY + px * 2.5, width: px * 1.6, height: px * 0.8
                )),
                with: .color(Color(red: 1.0, green: 0.5, blue: 0.5))
            )
        }

        ctx.drawLayer { layer in
            let tailX = tartX - px * 2
            let tailY = tartY + px * 1.5 + CGFloat(bounce)
            layer.fill(
                RoundedRectangle(cornerRadius: 1).path(in: CGRect(
                    x: tailX, y: tailY, width: px * 2.5, height: px * 1.5
                )),
                with: .color(Color(red: 0.6, green: 0.6, blue: 0.6))
            )
        }

        ctx.drawLayer { layer in
            for fx: CGFloat in [0.5, 3.5] {
                layer.fill(
                    Circle().path(in: CGRect(
                        x: tartX + fx * px,
                        y: tartY + px * 5 + CGFloat(bounce),
                        width: px * 1.5, height: px * 1
                    )),
                    with: .color(Color(red: 0.55, green: 0.55, blue: 0.55))
                )
            }
        }
    }
}
