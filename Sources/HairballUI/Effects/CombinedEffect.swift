import SwiftUI

/// Combines multiple effects — first draws text, rest layer decorations on top.
public struct CombinedEffect: StreamingTextEffect {
    public let effects: [any StreamingTextEffect]

    public init(_ effects: any StreamingTextEffect...) {
        self.effects = effects
    }

    public init(_ effects: [any StreamingTextEffect]) {
        self.effects = effects
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        guard let first = effects.first else { return }
        first.draw(layout: layout, revealedCount: revealedCount, settledCount: settledCount, time: time, in: &ctx)
        for effect in effects.dropFirst() {
            ctx.drawLayer { layer in
                effect.draw(layout: layout, revealedCount: revealedCount, settledCount: settledCount, time: time, in: &layer)
            }
        }
    }
}

extension StreamingTextEffect {
    /// Combine this effect with another. First draws text, second adds decorations.
    public func combined(with other: any StreamingTextEffect) -> CombinedEffect {
        CombinedEffect(self, other)
    }
}
