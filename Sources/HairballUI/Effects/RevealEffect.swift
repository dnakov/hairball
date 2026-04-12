import SwiftUI

/// Simple reveal — characters appear one by one, nothing drawn past cursor.
public struct RevealEffect: StreamingTextEffect {
    public init() {}

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            context.draw(slice)
            return true
        }, context: &ctx)
    }
}
