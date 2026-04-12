import SwiftUI

/// Wave — characters near the cursor bounce up and down.
public struct WaveRevealEffect: StreamingTextEffect {
    public let amplitude: CGFloat
    public let wavelength: Int
    public init(amplitude: CGFloat = 4, wavelength: Int = 8) {
        self.amplitude = amplitude
        self.wavelength = wavelength
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        let trail = effectiveTrail(ownTrail: wavelength, revealedCount: revealedCount, settledCount: settledCount)
        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let distFromCursor = revealedCount - index
            if distFromCursor <= trail {
                let phase = Double(distFromCursor) / Double(trail) * .pi
                let yOffset = sin(phase) * Double(amplitude)
                var c = context
                c.translateBy(x: 0, y: yOffset)
                c.draw(slice)
            } else {
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
