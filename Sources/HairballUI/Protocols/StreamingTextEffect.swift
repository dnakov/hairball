import SwiftUI

/// A streaming text effect that controls how text appears during reveal.
/// Uses iOS 18's `TextRenderer` for per-glyph control.
///
/// - `revealedCount`: how many characters are visible (cursor position)
/// - `settledCount`: how many characters are "done animating" (based on granularity)
/// - `time`: continuous animation time in seconds (ticks at 60fps while streaming)
///
/// Characters `< settledCount` should be drawn normally.
/// Characters `>= settledCount` and `< revealedCount` are in the active effect zone.
/// Characters `>= revealedCount` are not yet revealed.
///
/// `time` provides a continuous animation signal independent of `revealedCount`.
/// Use it for effects that need to animate between token arrivals (e.g. Matrix rain).
/// In `.character` granularity `time` still ticks but most effects won't need it.

public protocol StreamingTextEffect: Sendable {
    func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in context: inout GraphicsContext)
}

// MARK: - Helpers

extension StreamingTextEffect {
    /// Iterates all character slices across the layout, calling `handler` with
    /// the global character index and the slice. Return `true` to continue, `false` to stop.
    public func forEachSlice(
        in layout: Text.Layout,
        _ handler: (Int, Text.Layout.RunSlice, inout GraphicsContext) -> Bool,
        context: inout GraphicsContext
    ) {
        var globalIndex = 0
        for line in layout {
            for run in line {
                for slice in run {
                    if !handler(globalIndex, slice, &context) { return }
                    globalIndex += 1
                }
            }
        }
    }

    /// Computes the effective trail length: the effect's own trail, expanded to cover
    /// all unsettled characters when granularity pushes settledCount behind the cursor.
    /// Use this instead of a hardcoded trail width to respect `RevealGranularity`.
    public func effectiveTrail(ownTrail: Int, revealedCount: Int, settledCount: Int) -> Int {
        ownTrail
    }

    /// Counts the total number of character slices in the layout.
    public func totalCharCount(in layout: Text.Layout) -> Int {
        var count = 0
        for line in layout {
            for run in line {
                for _ in run { count += 1 }
            }
        }
        return count
    }

    /// Draws all revealed slices normally and returns the cursor point (position after
    /// the last revealed character). Use this for effects that draw text normally and
    /// then add an overlay at the cursor (glow, sparkle, nyan cat, etc).
    public func drawRevealedAndGetCursorPoint(
        in layout: Text.Layout,
        revealedCount: Int,
        context: inout GraphicsContext
    ) -> CGPoint? {
        var cursorPoint: CGPoint?
        forEachSlice(in: layout, { index, slice, ctx in
            guard index < revealedCount else { return false }
            ctx.draw(slice)
            if index == revealedCount - 1 {
                let b = slice.typographicBounds
                cursorPoint = CGPoint(x: b.origin.x + b.width, y: b.origin.y)
            }
            return true
        }, context: &context)
        return cursorPoint
    }
}

// MARK: - Reveal Granularity

/// Controls how the effect's "active zone" is scoped.
/// Text always reveals character-by-character — this controls when characters
/// transition from the effect's animating state to settled/normal rendering.
public enum RevealGranularity: Sendable, Equatable {
    /// Characters settle as the cursor passes (default). Effect uses its own trail length.
    case character
    /// Characters stay in the effect zone until the entire block is complete.
    case block
    /// Characters settle in chunks of N.
    case chunk(Int)
    /// Characters settle line by line (based on layout lines).
    case line
}

// MARK: - Renderer Bridge

struct StreamingEffectRenderer: TextRenderer {
    let effect: any StreamingTextEffect
    let revealedCount: Int
    let granularity: RevealGranularity
    let blockComplete: Bool
    let time: Double

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let totalGlyphs = layout.flatMap { $0 }.flatMap { $0 }.count
        // If the block is fully revealed (cursor has moved past), treat as settled
        let effectiveComplete = blockComplete || revealedCount >= totalGlyphs

        let settled: Int
        switch granularity {
        case .character:
            settled = revealedCount
        case .block:
            settled = effectiveComplete ? revealedCount : 0
        case .chunk(let n):
            let clamped = max(n, 1)
            if effectiveComplete {
                settled = revealedCount
            } else {
                settled = (revealedCount / clamped) * clamped
            }
        case .line:
            if effectiveComplete {
                settled = revealedCount
            } else {
                settled = settledToLine(revealedCount, layout: layout)
            }
        }

        if settled >= revealedCount && effectiveComplete {
            for line in layout { for run in line { for slice in run { ctx.draw(slice) } } }
            return
        }

        effect.draw(layout: layout, revealedCount: revealedCount, settledCount: settled, time: time, in: &ctx)
    }

    private func settledToLine(_ revealed: Int, layout: Text.Layout) -> Int {
        var total = 0
        for layoutLine in layout {
            var lineEnd = total
            for run in layoutLine {
                for _ in run { lineEnd += 1 }
            }
            if revealed < lineEnd {
                return total
            }
            total = lineEnd
        }
        return total
    }
}

// MARK: - Environment Keys

private struct StreamingTextEffectKey: EnvironmentKey {
    static let defaultValue: (any StreamingTextEffect)? = nil
}

private struct RevealGranularityKey: EnvironmentKey {
    static let defaultValue: RevealGranularity = .character
}

extension EnvironmentValues {
    public var streamingTextEffect: (any StreamingTextEffect)? {
        get { self[StreamingTextEffectKey.self] }
        set { self[StreamingTextEffectKey.self] = newValue }
    }

    public var revealGranularity: RevealGranularity {
        get { self[RevealGranularityKey.self] }
        set { self[RevealGranularityKey.self] = newValue }
    }
}

extension View {
    public func streamingTextEffect(_ effect: any StreamingTextEffect) -> some View {
        environment(\.streamingTextEffect, effect)
    }

    public func revealGranularity(_ granularity: RevealGranularity) -> some View {
        environment(\.revealGranularity, granularity)
    }
}
