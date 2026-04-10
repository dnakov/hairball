import SwiftUI
import SwiftMath

// MARK: - MathLabelView (UIViewRepresentable / NSViewRepresentable)

#if canImport(UIKit)
struct MathLabelView: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: UIColor
    let labelMode: MTMathUILabelMode

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = labelMode
        label.textAlignment = .center
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = labelMode
    }
}
#elseif canImport(AppKit)
struct MathLabelView: NSViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: NSColor
    let labelMode: MTMathUILabelMode

    func makeNSView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = labelMode
        label.textAlignment = .center
        label.layer?.backgroundColor = NSColor.clear.cgColor
        return label
    }

    func updateNSView(_ label: MTMathUILabel, context: Context) {
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = labelMode
    }
}
#endif

// MARK: - LatexBlockView

public struct LatexBlockView: View {
    @Environment(\.markdownTheme) private var theme

    private let content: String

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        let textColor = makeMTColor(from: theme.foregroundColor)

        VStack(alignment: .center, spacing: 0) {
            MathLabelView(
                latex: content,
                fontSize: theme.bodyFontSize * 1.2,
                textColor: textColor,
                labelMode: .display
            )
            .frame(minHeight: theme.bodyFontSize * 2)
        }
        .padding(theme.codeBlock.padding)
        .frame(maxWidth: .infinity)
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
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
