import SwiftUI
import Hairball
import SwiftMath

// MARK: - LaTeX Image Cache

/// Thread-safe cache for rendered inline LaTeX images.
/// Avoids re-rendering the same LaTeX string on every SwiftUI view update.
final class LaTeXImageCache: @unchecked Sendable {
    static let shared = LaTeXImageCache()

    private var cache: [String: MTImage] = [:]
    private let lock = NSLock()

    func image(for latex: String, fontSize: CGFloat, textColor: MTColor) -> MTImage? {
        let key = "\(latex)-\(fontSize)-\(textColor.hashValue)"
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var mathImage = MathImage(latex: latex, fontSize: fontSize, textColor: textColor, labelMode: .text)
        let (_, rendered, _) = mathImage.asImage()

        if let rendered {
            lock.lock()
            cache[key] = rendered
            lock.unlock()
        }
        return rendered
    }

    func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

// MARK: - InlineStyle

public struct InlineStyle {
    public var font: Font?
    public var fontWeight: Font.Weight?
    public var italic: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var foregroundColor: Color?
    public var backgroundColor: Color?
    public var kern: CGFloat?
    public var tracking: CGFloat?
    public var baselineOffset: CGFloat?

    public init(
        font: Font? = nil,
        fontWeight: Font.Weight? = nil,
        italic: Bool = false,
        strikethrough: Bool = false,
        underline: Bool = false,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        kern: CGFloat? = nil,
        tracking: CGFloat? = nil,
        baselineOffset: CGFloat? = nil
    ) {
        self.font = font
        self.fontWeight = fontWeight
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.kern = kern
        self.tracking = tracking
        self.baselineOffset = baselineOffset
    }

    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text {
        var result = text
        if let font { result = result.font(font) }
        if let fontWeight { result = result.fontWeight(fontWeight) }
        if italic { result = result.italic() }
        if strikethrough { result = result.strikethrough() }
        if underline { result = result.underline() }
        if let foregroundColor { result = result.foregroundColor(foregroundColor) }
        if let kern { result = result.kerning(kern) }
        if let tracking { result = result.tracking(tracking) }
        if let baselineOffset { result = result.baselineOffset(baselineOffset) }
        return result
    }

    public func merging(_ other: InlineStyle) -> InlineStyle {
        InlineStyle(
            font: other.font ?? font,
            fontWeight: other.fontWeight ?? fontWeight,
            italic: other.italic || italic,
            strikethrough: other.strikethrough || strikethrough,
            underline: other.underline || underline,
            foregroundColor: other.foregroundColor ?? foregroundColor,
            backgroundColor: other.backgroundColor ?? backgroundColor,
            kern: other.kern ?? kern,
            tracking: other.tracking ?? tracking,
            baselineOffset: other.baselineOffset ?? baselineOffset
        )
    }
}

// MARK: - Inline Rendering

/// A segment produced during inline rendering. Most content is collected into
/// an `AttributedString`, but certain nodes (e.g. LaTeX images) can only be
/// represented as a `SwiftUI.Text` value and must be kept separate.
private enum InlineSegment {
    case attributed(AttributedString)
    case textView(SwiftUI.Text)
}

public struct InlineTextRenderer {
    let theme: MarkdownTheme

    public init(theme: MarkdownTheme) {
        self.theme = theme
    }

    public func render(_ nodes: [InlineNode], baseStyle: InlineStyle = InlineStyle()) -> SwiftUI.Text {
        let segments = renderSegments(nodes, style: baseStyle)
        return combineSegments(segments)
    }

    /// Renders inline nodes into a single `AttributedString`.
    /// Used by the TextRenderer path (iOS 18+) which handles splitting at the render level.
    public func renderToAttributedString(_ nodes: [InlineNode], baseStyle: InlineStyle = InlineStyle()) -> AttributedString {
        let segments = renderSegments(nodes, style: baseStyle)
        return mergeAttributedSegments(segments)
    }

    /// Splits rendered inline content into two `AttributedString` halves at a character boundary.
    ///
    /// Splits the rendered attributed string into two halves at a character boundary.
    public func renderAndSplit(
        _ nodes: [InlineNode],
        baseStyle: InlineStyle = InlineStyle(),
        at characterIndex: Int
    ) -> (revealed: AttributedString, fresh: AttributedString) {
        let segments = renderSegments(nodes, style: baseStyle)
        let fullAttr = mergeAttributedSegments(segments)
        let parts = fullAttr.split(at: characterIndex)
        return (parts.before, parts.after)
    }

    /// Merges all attributed segments into a single AttributedString (dropping image segments).
    private func mergeAttributedSegments(_ segments: [InlineSegment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .attributed(let attr):
                result += attr
            case .textView:
                // Can't merge image-based Text into AttributedString; skip
                break
            }
        }
        return result
    }

    // MARK: - Segment-based rendering

    private func renderSegments(_ nodes: [InlineNode], style: InlineStyle) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        for node in nodes {
            segments += renderNodeSegments(node, style: style)
        }
        return segments
    }

    private func renderNodeSegments(_ node: InlineNode, style: InlineStyle) -> [InlineSegment] {
        switch node {
        case .text(let string):
            var attr = AttributedString(string)
            applyStyle(style, to: &attr)
            return [.attributed(attr)]

        case .emphasis(let children):
            let emphStyle = style.merging(InlineStyle(italic: true))
            return renderSegments(children, style: emphStyle)

        case .strong(let children):
            let strongStyle = style.merging(InlineStyle(fontWeight: .bold))
            return renderSegments(children, style: strongStyle)

        case .strikethrough(let children):
            let strikeStyle = style.merging(InlineStyle(strikethrough: true))
            return renderSegments(children, style: strikeStyle)

        case .inlineCode(let code):
            var attr = AttributedString(code)
            attr.font = theme.inlineCode.font
            attr.foregroundColor = theme.inlineCode.textColor
            attr.backgroundColor = theme.inlineCode.backgroundColor
            if let baselineOffset = style.baselineOffset {
                attr.baselineOffset = baselineOffset
            }
            return [.attributed(attr)]

        case .link(let destination, _, let children):
            var attr = renderAttributedString(children, style: style)
            if let url = URL(string: destination) {
                attr.link = url
            }
            attr.foregroundColor = theme.link.color
            if theme.link.underline {
                attr.underlineStyle = .single
            }
            return [.attributed(attr)]

        case .image(_, _, let children):
            return renderSegments(children, style: style)

        case .softBreak:
            switch theme.softBreakMode {
            case .space:
                return [.attributed(AttributedString(" "))]
            case .lineBreak:
                return [.attributed(AttributedString("\n"))]
            }

        case .hardBreak, .lineBreak:
            return [.attributed(AttributedString("\n"))]

        case .inlineHTML(let html):
            var attr = AttributedString(html)
            applyStyle(style, to: &attr)
            return [.attributed(attr)]

        case .latex(let content):
            let textColor = makeMTColor(from: theme.foregroundColor)
            if let image = LaTeXImageCache.shared.image(for: content, fontSize: theme.bodyFontSize, textColor: textColor) {
                #if canImport(UIKit)
                return [.textView(SwiftUI.Text(Image(uiImage: image)))]
                #elseif canImport(AppKit)
                return [.textView(SwiftUI.Text(Image(nsImage: image)))]
                #endif
            } else {
                var attr = AttributedString(content)
                let latexStyle = style.merging(InlineStyle(
                    font: .system(size: theme.bodyFontSize, design: .serif)
                ))
                applyStyle(latexStyle, to: &attr)
                return [.attributed(attr)]
            }

        case .citation(let index, let url, let title):
            let display = title ?? url ?? "[\(index)]"
            var attr = AttributedString(display)
            attr.font = .system(size: theme.citation.fontSize)
            attr.foregroundColor = theme.citation.textColor
            return [.attributed(attr)]

        case .customInline(_, let content):
            var attr = AttributedString(content)
            applyStyle(style, to: &attr)
            return [.attributed(attr)]
        }
    }

    // MARK: - AttributedString helpers

    /// Renders inline nodes into a single `AttributedString`. Used for contexts
    /// like link children where we need a contiguous attributed string.
    private func renderAttributedString(_ nodes: [InlineNode], style: InlineStyle) -> AttributedString {
        var result = AttributedString()
        for node in nodes {
            for segment in renderNodeSegments(node, style: style) {
                switch segment {
                case .attributed(let attr):
                    result += attr
                case .textView:
                    break
                }
            }
        }
        return result
    }

    private func applyStyle(_ style: InlineStyle, to attrStr: inout AttributedString) {
        if let font = style.font {
            attrStr.font = font
        }
        if let fontWeight = style.fontWeight {
            attrStr.font = (attrStr.font ?? .body).weight(fontWeight)
        }
        if style.italic {
            attrStr.font = (attrStr.font ?? .body).italic()
        }
        if style.strikethrough {
            attrStr.strikethroughStyle = .single
        }
        if style.underline {
            attrStr.underlineStyle = .single
        }
        if let foregroundColor = style.foregroundColor {
            attrStr.foregroundColor = foregroundColor
        }
        if let kern = style.kern {
            attrStr.kern = kern
        }
        if let tracking = style.tracking {
            attrStr.tracking = tracking
        }
        if let baselineOffset = style.baselineOffset {
            attrStr.baselineOffset = baselineOffset
        }
    }

    /// Combines segments into a single `SwiftUI.Text` by merging adjacent
    /// attributed strings and concatenating with any image-based Text views.
    private func combineSegments(_ segments: [InlineSegment]) -> SwiftUI.Text {
        var result = SwiftUI.Text("")
        var pendingAttr = AttributedString()

        for segment in segments {
            switch segment {
            case .attributed(let attr):
                pendingAttr += attr
            case .textView(let text):
                if !pendingAttr.characters.isEmpty {
                    result = result + SwiftUI.Text(pendingAttr)
                    pendingAttr = AttributedString()
                }
                result = result + text
            }
        }

        if !pendingAttr.characters.isEmpty {
            result = result + SwiftUI.Text(pendingAttr)
        }

        return result
    }
}

// MARK: - Convenience Extensions

extension [InlineNode] {
    public func renderText(theme: MarkdownTheme) -> SwiftUI.Text {
        InlineTextRenderer(theme: theme).render(self)
    }

    public var plainText: String {
        map { node -> String in
            switch node {
            case .text(let string): return string
            case .emphasis(let children): return children.plainText
            case .strong(let children): return children.plainText
            case .strikethrough(let children): return children.plainText
            case .inlineCode(let code): return code
            case .link(_, _, let children): return children.plainText
            case .image(_, _, let children): return children.plainText
            case .softBreak: return " "
            case .hardBreak, .lineBreak: return "\n"
            case .inlineHTML(let html): return html
            case .latex(let content): return content
            case .citation(let index, _, let title): return title ?? "[\(index)]"
            case .customInline(_, let content): return content
            }
        }.joined()
    }
}

// MARK: - MTColor from SwiftUI.Color

private func makeMTColor(from color: Color) -> MTColor {
    #if canImport(UIKit)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return MTColor(red: r, green: g, blue: b, alpha: a)
    #elseif canImport(AppKit)
    let nsColor = NSColor(color)
    if let converted = nsColor.usingColorSpace(.sRGB) {
        return MTColor(red: converted.redComponent, green: converted.greenComponent, blue: converted.blueComponent, alpha: converted.alphaComponent)
    }
    return MTColor(white: 0, alpha: 1)
    #endif
}

// MARK: - AttributedString Helpers

extension AttributedString {
    /// Returns the first `count` characters, or the whole string if shorter.
    func prefix(_ count: Int) -> AttributedString {
        guard count > 0 else { return AttributedString() }
        guard count < characters.count else { return self }
        let end = characters.index(startIndex, offsetBy: count)
        return AttributedString(self[startIndex..<end])
    }

    /// Splits at a character index, returning (before, after).
    func split(at characterIndex: Int) -> (before: AttributedString, after: AttributedString) {
        let clamped = min(max(characterIndex, 0), characters.count)
        if clamped == 0 { return (AttributedString(), self) }
        if clamped >= characters.count { return (self, AttributedString()) }
        let idx = characters.index(startIndex, offsetBy: clamped)
        return (AttributedString(self[startIndex..<idx]), AttributedString(self[idx...]))
    }
}
