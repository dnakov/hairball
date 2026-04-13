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

            // Unsettled but revealed — matrix decode with gradual real-char reveal
            let b = slice.typographicBounds
            let colHash = abs(Int(x * 7.3 + 100)) &+ 1

            // How far behind the cursor this char is (0 = just revealed, large = old)
            let age = revealedCount - index
            let decodeDelay = 3 + (colHash % 5) // 3-7 frames of scramble
            let decoded = age > decodeDelay

            // Rain positioning (shared by scrambled and decoded chars)
            let yNorm = (y - minY) / totalHeight
            let rainTime = time > 0 ? time : Double(revealedCount) / 60.0
            let rainSpeed = 0.5 + Double(colHash % 7) * 0.3
            let rainOffset = Double(colHash % 13) / 13.0
            let rainPos = fmod(rainTime * rainSpeed + rainOffset, 1.6) - 0.3
            let distFromHead = yNorm - rainPos
            let streakLen = 0.15 + Double(colHash % 5) * 0.04

            let isHead = distFromHead >= -0.02 && distFromHead <= 0.02
            let brightness: Double
            if isHead {
                brightness = 1.0
            } else if distFromHead < -0.02 && distFromHead >= -streakLen {
                let t = abs(distFromHead) / streakLen
                brightness = max(0.3, 0.9 * (1.0 - t))
            } else {
                let flicker = ((frame * 3 + index * 7) % 10)
                brightness = flicker < 2 ? 0.35 : 0.15
            }

            if decoded {
                // Decoded — draw the REAL character but with matrix green tint
                // that pulses with the rain. Settled chars draw plain.
                if index < settledCount {
                    ctx.draw(slice)
                } else {
                    let rainGlow = isHead ? 0.6 : max(brightness * 0.3, 0.05)
                    var c = ctx
                    c.addFilter(.colorMultiply(matrixColor.opacity(rainGlow)))
                    c.draw(slice)
                }
                continue
            }

            // Still scrambling — show cycling random matrix glyphs
            let speed = 2 + (colHash % 4)
            let glyphFrame = (frame + colHash * 31) / speed
            let seed = ((glyphFrame * 17 + index * 13) % Self.charCount + Self.charCount) % Self.charCount
            let ch = Self.matrixChars[seed]

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
