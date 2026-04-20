import SwiftUI

// MARK: - Supporting Types

/// RGBA color for scripted effects.
public struct EffectColor: Sendable, Equatable {
    public let r, g, b, a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Create from hue/saturation/brightness (all 0–1).
    public static func hsb(_ h: Double, _ s: Double, _ b: Double, _ a: Double = 1.0) -> EffectColor {
        guard s > 0 else { return EffectColor(b, b, b, a) }
        let hue = h - floor(h)
        let sector = Int(hue * 6) % 6
        let f = hue * 6 - Double(sector)
        let p = b * (1 - s)
        let q = b * (1 - s * f)
        let t = b * (1 - s * (1 - f))
        switch sector {
        case 0: return EffectColor(b, t, p, a)
        case 1: return EffectColor(q, b, p, a)
        case 2: return EffectColor(p, b, t, a)
        case 3: return EffectColor(p, q, b, a)
        case 4: return EffectColor(t, p, b, a)
        default: return EffectColor(b, p, q, a)
        }
    }

    public func withAlpha(_ a: Double) -> EffectColor { EffectColor(r, g, b, a) }

    public static let white = EffectColor(1, 1, 1)
    public static let black = EffectColor(0, 0, 0)
    public static let clear = EffectColor(0, 0, 0, 0)

    var swiftUIColor: Color { Color(red: r, green: g, blue: b).opacity(a) }
}

/// Typographic bounds for a single glyph.
public struct GlyphInfo: Sendable {
    /// Left edge X.
    public let x: Double
    /// Baseline Y.
    public let y: Double
    /// Advance width.
    public let width: Double
    /// Distance above baseline.
    public let ascent: Double
    /// Distance below baseline.
    public let descent: Double
    /// Normalized Y within block (0 = top, 1 = bottom).
    public let yNorm: Double

    public var centerX: Double { x + width / 2 }
    public var height: Double { ascent + descent }
}

// MARK: - Protocol

/// Drawing context for scripted streaming text effects.
///
/// Provides glyph data extraction and the core drawing primitives that
/// are tedious to wire up per-platform. For anything beyond these basics
/// (gradients, images, clip masks, shaders), implement `StreamingTextEffect`
/// directly for full `GraphicsContext` access.
///
/// ## Drawing model
/// - `save()`/`restore()` push/pop transforms and appearance state.
/// - `beginLayer()`/`endLayer(blur:opacity:)` create compositing groups.
///
public protocol ScriptableEffectContext: AnyObject {

    // MARK: State

    var revealedCount: Int { get }
    var settledCount: Int { get }
    var time: Double { get }
    var glyphCount: Int { get }
    var blockComplete: Bool { get }

    // MARK: Glyph Data

    /// Bounds for any glyph (0..<glyphCount), including unrevealed.
    func glyph(_ index: Int) -> GlyphInfo

    /// Position after the last revealed glyph, or nil.
    func cursorPoint() -> (x: Double, y: Double)?

    /// Bounding box of all glyphs: (minX, minY, maxX, maxY).
    func blockBounds() -> (minX: Double, minY: Double, maxX: Double, maxY: Double)

    /// Trail length expanded for granularity: max(ownTrail, revealedCount - settledCount).
    func effectiveTrail(_ ownTrail: Int) -> Int

    // MARK: Transform

    func save()
    func restore()
    func translate(_ x: Double, _ y: Double)
    func scale(_ x: Double, _ y: Double)

    // MARK: Appearance

    func setOpacity(_ opacity: Double)
    func setColorMultiply(_ color: EffectColor)

    // MARK: Layers

    func beginLayer()
    func endLayer(blur: Double, opacity: Double)

    // MARK: Drawing

    /// Draw a glyph with its original styled appearance.
    func drawGlyph(_ index: Int)

    /// Draw replacement text (for character substitution effects like Matrix).
    func drawText(_ string: String, x: Double, y: Double, size: Double,
                  color: EffectColor, monospaced: Bool)

    /// Fill a circle.
    func fillCircle(x: Double, y: Double, radius: Double, color: EffectColor)

    /// Fill a rectangle.
    func fillRect(x: Double, y: Double, width: Double, height: Double, color: EffectColor)

    /// Stroke a circle outline.
    func strokeCircle(x: Double, y: Double, radius: Double,
                      color: EffectColor, lineWidth: Double)
}

// MARK: - Convenience overloads

extension ScriptableEffectContext {
    public func endLayer() { endLayer(blur: 0, opacity: 1) }
    public func endLayer(blur: Double) { endLayer(blur: blur, opacity: 1) }
    public func endLayer(opacity: Double) { endLayer(blur: 0, opacity: opacity) }
    public func scale(_ s: Double) { scale(s, s) }
    public func drawText(_ string: String, x: Double, y: Double, size: Double, color: EffectColor) {
        drawText(string, x: x, y: y, size: size, color: color, monospaced: false)
    }
}

// MARK: - Provider

/// Implement this to supply draw logic from any runtime (Lua, JS, closures, etc.).
public protocol ScriptedEffectProvider: Sendable {
    func draw(context: any ScriptableEffectContext)
}

// MARK: - ScriptedEffect

/// Wraps a `ScriptedEffectProvider` or closure as a `StreamingTextEffect`.
public struct ScriptedEffect: StreamingTextEffect {
    private let _draw: @Sendable (any ScriptableEffectContext) -> Void

    public init(_ provider: any ScriptedEffectProvider) {
        self._draw = { provider.draw(context: $0) }
    }

    public init(_ draw: @escaping @Sendable (any ScriptableEffectContext) -> Void) {
        self._draw = draw
    }

    public func draw(layout: Text.Layout, revealedCount: Int, settledCount: Int,
                     time: Double, in ctx: inout GraphicsContext) {
        let bridge = GraphicsContextBridge(
            ctx: ctx, layout: layout,
            revealedCount: revealedCount, settledCount: settledCount, time: time
        )
        _draw(bridge)
        ctx = bridge.rootContext
    }
}

// MARK: - Internal Bridge

final class GraphicsContextBridge: ScriptableEffectContext {
    private var ctxStack: [GraphicsContext]
    private let slices: [(Text.Layout.RunSlice, GlyphInfo)]
    private let _cursorPoint: (x: Double, y: Double)?
    private let _blockBounds: (minX: Double, minY: Double, maxX: Double, maxY: Double)

    let revealedCount: Int
    let settledCount: Int
    let time: Double
    let blockComplete: Bool
    var glyphCount: Int { slices.count }

    var rootContext: GraphicsContext {
        get { ctxStack[0] }
        set { ctxStack[0] = newValue }
    }

    private var layerStack: [[DrawCommand]] = []
    private var isInLayer: Bool { !layerStack.isEmpty }

    init(ctx: GraphicsContext, layout: Text.Layout,
         revealedCount: Int, settledCount: Int, time: Double,
         blockComplete: Bool = false) {
        self.ctxStack = [ctx]
        self.revealedCount = revealedCount
        self.settledCount = settledCount
        self.time = time
        self.blockComplete = blockComplete

        var extracted: [(Text.Layout.RunSlice, GlyphInfo)] = []
        var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var cursor: (x: Double, y: Double)?

        var gi = 0
        for line in layout {
            for run in line {
                for slice in run {
                    let b = slice.typographicBounds
                    extracted.append((slice, GlyphInfo(
                        x: b.origin.x, y: b.origin.y, width: b.width,
                        ascent: b.ascent, descent: b.descent, yNorm: 0
                    )))
                    minY = min(minY, b.origin.y - b.ascent)
                    maxY = max(maxY, b.origin.y + b.descent)
                    minX = min(minX, b.origin.x)
                    maxX = max(maxX, b.origin.x + b.width)
                    if gi == revealedCount - 1 {
                        cursor = (Double(b.origin.x + b.width), Double(b.origin.y))
                    }
                    gi += 1
                }
            }
        }

        let totalHeight = max(maxY - minY, 1)
        for i in extracted.indices {
            let g = extracted[i].1
            extracted[i].1 = GlyphInfo(
                x: g.x, y: g.y, width: g.width,
                ascent: g.ascent, descent: g.descent,
                yNorm: (g.y - minY) / totalHeight
            )
        }

        self.slices = extracted
        self._cursorPoint = cursor
        self._blockBounds = extracted.isEmpty
            ? (0, 0, 0, 0) : (minX, minY, maxX, maxY)
    }

    // MARK: Data

    func glyph(_ index: Int) -> GlyphInfo { slices[index].1 }
    func cursorPoint() -> (x: Double, y: Double)? { _cursorPoint }
    func blockBounds() -> (minX: Double, minY: Double, maxX: Double, maxY: Double) { _blockBounds }
    func effectiveTrail(_ ownTrail: Int) -> Int { max(ownTrail, revealedCount - settledCount) }

    // MARK: Transform

    private var currentCtx: GraphicsContext {
        get { ctxStack[ctxStack.count - 1] }
        set { ctxStack[ctxStack.count - 1] = newValue }
    }

    func save() {
        if isInLayer { append(.save); return }
        ctxStack.append(currentCtx)
    }

    func restore() {
        if isInLayer { append(.restore); return }
        if ctxStack.count > 1 { ctxStack.removeLast() }
    }

    func translate(_ x: Double, _ y: Double) {
        if isInLayer { append(.translate(x, y)); return }
        currentCtx.translateBy(x: x, y: y)
    }

    func scale(_ x: Double, _ y: Double) {
        if isInLayer { append(.scale(x, y)); return }
        currentCtx.scaleBy(x: x, y: y)
    }

    // MARK: Appearance

    func setOpacity(_ opacity: Double) {
        if isInLayer { append(.setOpacity(opacity)); return }
        currentCtx.opacity = opacity
    }

    func setColorMultiply(_ color: EffectColor) {
        if isInLayer { append(.setColorMultiply(color)); return }
        currentCtx.addFilter(.colorMultiply(color.swiftUIColor))
    }

    // MARK: Layers

    func beginLayer() { layerStack.append([]) }

    func endLayer(blur: Double, opacity: Double) {
        guard let commands = layerStack.popLast() else { return }
        if isInLayer {
            append(.layer(commands, blur: blur, opacity: opacity))
        } else {
            currentCtx.drawLayer { [slices] layer in
                if opacity != 1 { layer.opacity = opacity }
                Self.replay(commands, into: &layer, slices: slices)
                if blur > 0 { layer.addFilter(.blur(radius: blur)) }
            }
        }
    }

    // MARK: Drawing

    func drawGlyph(_ index: Int) {
        if isInLayer { append(.drawGlyph(index)); return }
        currentCtx.draw(slices[index].0)
    }

    func drawText(_ string: String, x: Double, y: Double, size: Double,
                  color: EffectColor, monospaced: Bool) {
        if isInLayer { append(.drawText(string, x: x, y: y, size: size, color: color, mono: monospaced)); return }
        Self.executeDrawText(string, x: x, y: y, size: size, color: color, monospaced: monospaced, in: &currentCtx)
    }

    func fillCircle(x: Double, y: Double, radius: Double, color: EffectColor) {
        if isInLayer { append(.fillCircle(x: x, y: y, r: radius, color: color)); return }
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        currentCtx.fill(Circle().path(in: rect), with: .color(color.swiftUIColor))
    }

    func fillRect(x: Double, y: Double, width: Double, height: Double, color: EffectColor) {
        if isInLayer { append(.fillRect(x: x, y: y, w: width, h: height, color: color)); return }
        currentCtx.fill(Path(CGRect(x: x, y: y, width: width, height: height)), with: .color(color.swiftUIColor))
    }

    func strokeCircle(x: Double, y: Double, radius: Double,
                      color: EffectColor, lineWidth: Double) {
        if isInLayer { append(.strokeCircle(x: x, y: y, r: radius, color: color, lw: lineWidth)); return }
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        currentCtx.stroke(Circle().path(in: rect), with: .color(color.swiftUIColor), lineWidth: lineWidth)
    }

    // MARK: Helpers

    private func append(_ cmd: DrawCommand) {
        layerStack[layerStack.count - 1].append(cmd)
    }

    static func executeDrawText(_ string: String, x: Double, y: Double, size: Double,
                                color: EffectColor, monospaced: Bool, in ctx: inout GraphicsContext) {
        ctx.drawLayer { layer in
            let font: Font = monospaced ? .system(size: size, design: .monospaced) : .system(size: size)
            let text = Text(string).font(font).foregroundColor(color.swiftUIColor)
            let resolved = layer.resolve(text)
            let measured = resolved.measure(in: CGSize(width: 200, height: 200))
            layer.draw(resolved, at: CGPoint(x: x + measured.width / 2, y: y))
        }
    }
}

// MARK: - Command Buffer

private enum DrawCommand {
    case save, restore
    case translate(Double, Double)
    case scale(Double, Double)
    case setOpacity(Double)
    case setColorMultiply(EffectColor)
    case drawGlyph(Int)
    case drawText(String, x: Double, y: Double, size: Double, color: EffectColor, mono: Bool)
    case fillCircle(x: Double, y: Double, r: Double, color: EffectColor)
    case fillRect(x: Double, y: Double, w: Double, h: Double, color: EffectColor)
    case strokeCircle(x: Double, y: Double, r: Double, color: EffectColor, lw: Double)
    case layer([DrawCommand], blur: Double, opacity: Double)
}

// MARK: - Replay

extension GraphicsContextBridge {
    fileprivate static func replay(_ commands: [DrawCommand], into ctx: inout GraphicsContext,
                                   slices: [(Text.Layout.RunSlice, GlyphInfo)]) {
        var stack: [GraphicsContext] = [ctx]
        for cmd in commands {
            switch cmd {
            case .save:                         stack.append(stack[stack.count - 1])
            case .restore:                      if stack.count > 1 { stack.removeLast() }
            case .translate(let x, let y):      stack[stack.count - 1].translateBy(x: x, y: y)
            case .scale(let x, let y):          stack[stack.count - 1].scaleBy(x: x, y: y)
            case .setOpacity(let a):            stack[stack.count - 1].opacity = a
            case .setColorMultiply(let c):      stack[stack.count - 1].addFilter(.colorMultiply(c.swiftUIColor))
            case .drawGlyph(let i):             stack[stack.count - 1].draw(slices[i].0)
            case .drawText(let s, let x, let y, let sz, let c, let m):
                executeDrawText(s, x: x, y: y, size: sz, color: c, monospaced: m, in: &stack[stack.count - 1])
            case .fillCircle(let x, let y, let r, let c):
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                stack[stack.count - 1].fill(Circle().path(in: rect), with: .color(c.swiftUIColor))
            case .fillRect(let x, let y, let w, let h, let c):
                stack[stack.count - 1].fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(c.swiftUIColor))
            case .strokeCircle(let x, let y, let r, let c, let lw):
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                stack[stack.count - 1].stroke(Circle().path(in: rect), with: .color(c.swiftUIColor), lineWidth: lw)
            case .layer(let cmds, let blur, let opacity):
                stack[stack.count - 1].drawLayer { layer in
                    if opacity != 1 { layer.opacity = opacity }
                    Self.replay(cmds, into: &layer, slices: slices)
                    if blur > 0 { layer.addFilter(.blur(radius: blur)) }
                }
            }
        }
        ctx = stack[0]
    }
}
