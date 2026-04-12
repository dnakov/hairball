import SwiftUI

/// Matrix Decode — characters appear as cycling random glyphs that simulate
/// the classic "character rain" effect. Rain streaks fall top-to-bottom through
/// columns, each at its own speed. The cursor's position drives the animation frame.
///
/// In `.character` granularity, characters decode into real text as the cursor
/// passes. In `.block` granularity, the entire block rains until complete, then
/// all characters decode at once.
public struct MatrixDecodeEffect: StreamingTextEffect {
    public let trailLength: Int
    public let matrixColor: Color
    public init(trailLength: Int = 8, matrixColor: Color = Color(red: 0.0, green: 0.9, blue: 0.0)) {
        self.trailLength = trailLength
        self.matrixColor = matrixColor
    }

    private static let matrixChars: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789$#@&%!?<>{}[]+=")
    private static let charCount = matrixChars.count

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int, time: Double, in ctx: inout GraphicsContext) {
        // Collect layout geometry
        var slices: [(Int, Text.Layout.RunSlice, CGFloat, CGFloat)] = []
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var globalIndex = 0
        for line in layout {
            for run in line {
                for slice in run {
                    let b = slice.typographicBounds
                    slices.append((globalIndex, slice, b.origin.x, b.origin.y))
                    minY = min(minY, b.origin.y - b.ascent)
                    maxY = max(maxY, b.origin.y + b.descent)
                    globalIndex += 1
                }
            }
        }

        let totalHeight = max(maxY - minY, 1)
        // Use continuous time for rain animation, fall back to revealedCount if time is 0
        let frame = time > 0 ? Int(time * 60) : revealedCount

        for (index, slice, x, y) in slices {
            if index < settledCount {
                ctx.draw(slice)
                continue
            }

            guard index < revealedCount else {
                // Unrevealed — dim ghost glyphs ahead of cursor
                let lookAhead = index - revealedCount
                if lookAhead < trailLength * 3 {
                    let b = slice.typographicBounds
                    let seed = ((frame * 7 + index * 13) % Self.charCount + Self.charCount) % Self.charCount
                    let ch = Self.matrixChars[seed]
                    let opacity = max(0, 1.0 - Double(lookAhead) / Double(trailLength * 3)) * 0.2
                    drawGlyph(ch, opacity: opacity, color: matrixColor, originX: b.origin.x, originY: b.origin.y, width: b.width, in: &ctx)
                }
                continue
            }

            // Unsettled but revealed — character rain
            let b = slice.typographicBounds

            // Column identity from x position (stable across frames)
            let colHash = abs(Int(x * 7.3 + 100)) &+ 1

            // Glyph cycling — each column has its own speed and phase
            let speed = 2 + (colHash % 4)
            let glyphFrame = (frame + colHash * 31) / speed
            let seed = ((glyphFrame * 17 + index * 13) % Self.charCount + Self.charCount) % Self.charCount
            let ch = Self.matrixChars[seed]

            // Normalize y position within the block: 0 = top, 1 = bottom
            let yNorm = (y - minY) / totalHeight

            // Rain head position falls top-to-bottom over time
            // Each column has a different speed and start offset
            let rainTime = time > 0 ? time : Double(revealedCount) / 60.0
            let rainSpeed = 0.5 + Double(colHash % 7) * 0.3      // units per second
            let rainOffset = Double(colHash % 13) / 13.0          // staggered start
            let rainPos = fmod(rainTime * rainSpeed + rainOffset, 1.6) - 0.3
            // rainPos sweeps from -0.3 to 1.3 then wraps — gives top entry and bottom exit

            let distFromHead = yNorm - rainPos
            let streakLen = 0.15 + Double(colHash % 5) * 0.04  // 0.15–0.35 of block height

            let brightness: Double
            if distFromHead >= -0.02 && distFromHead <= 0.02 {
                // Head of the rain drop — brightest
                brightness = 1.0
            } else if distFromHead > 0.02 && distFromHead <= streakLen {
                // Trail behind the head (above it since head moves down)
                // Wait — distFromHead > 0 means yNorm > rainPos, meaning below the head
                // Actually: head is at rainPos, trail is chars the head already passed (above)
                // So trail is where distFromHead < 0
                brightness = 0.1
            } else if distFromHead < -0.02 && distFromHead >= -streakLen {
                // Trail — head has passed this position going downward
                let t = abs(distFromHead) / streakLen
                brightness = max(0.1, 0.8 * (1.0 - t))
            } else {
                // Background — random dim flicker
                let flicker = ((frame * 3 + index * 7) % 10)
                brightness = flicker < 2 ? 0.25 : 0.08
            }

            let isHead = distFromHead >= -0.02 && distFromHead <= 0.02
            let color = isHead ? Color(red: 0.7, green: 1.0, blue: 0.7) : matrixColor

            drawGlyph(ch, opacity: brightness, color: color, originX: b.origin.x, originY: b.origin.y, width: b.width, in: &ctx)
        }
    }

    private func drawGlyph(
        _ ch: Character,
        opacity: Double,
        color: Color,
        originX: CGFloat,
        originY: CGFloat,
        width: CGFloat,
        in ctx: inout GraphicsContext
    ) {
        ctx.drawLayer { layer in
            let t = SwiftUI.Text(String(ch))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(color.opacity(opacity))
            let resolved = layer.resolve(t)
            let size = resolved.measure(in: CGSize(width: 100, height: 100))
            layer.draw(resolved, at: CGPoint(
                x: originX + width / 2 - size.width / 2,
                y: originY - size.height / 2
            ))
        }
    }
}
