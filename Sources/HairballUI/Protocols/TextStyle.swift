import SwiftUI

// MARK: - TextStyle Protocol

/// A protocol for defining reusable text styles that can be applied to SwiftUI `Text` views.
public protocol TextStyle {
    func apply(to text: SwiftUI.Text) -> SwiftUI.Text
}

// MARK: - Built-in Text Styles

public struct FontTextStyle: TextStyle {
    public let font: Font
    public init(_ font: Font) { self.font = font }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.font(font) }
}

public struct ForegroundColorTextStyle: TextStyle {
    public let color: Color
    public init(_ color: Color) { self.color = color }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.foregroundColor(color) }
}

public struct FontWeightTextStyle: TextStyle {
    public let weight: Font.Weight
    public init(_ weight: Font.Weight) { self.weight = weight }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.fontWeight(weight) }
}

public struct ItalicTextStyle: TextStyle {
    public init() {}
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.italic() }
}

public struct StrikethroughTextStyle: TextStyle {
    public let isActive: Bool
    public let color: Color?
    public init(isActive: Bool = true, color: Color? = nil) {
        self.isActive = isActive
        self.color = color
    }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.strikethrough(isActive, color: color) }
}

public struct UnderlineTextStyle: TextStyle {
    public let isActive: Bool
    public let color: Color?
    public init(isActive: Bool = true, color: Color? = nil) {
        self.isActive = isActive
        self.color = color
    }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.underline(isActive, color: color) }
}

public struct KerningTextStyle: TextStyle {
    public let kerning: CGFloat
    public init(_ kerning: CGFloat) { self.kerning = kerning }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.kerning(kerning) }
}

public struct TrackingTextStyle: TextStyle {
    public let tracking: CGFloat
    public init(_ tracking: CGFloat) { self.tracking = tracking }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.tracking(tracking) }
}

public struct BaselineOffsetTextStyle: TextStyle {
    public let offset: CGFloat
    public init(_ offset: CGFloat) { self.offset = offset }
    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text { text.baselineOffset(offset) }
}

// MARK: - Composite Text Style

public struct CompositeTextStyle: TextStyle {
    public let styles: [any TextStyle]

    public init(_ styles: [any TextStyle]) {
        self.styles = styles
    }

    public func apply(to text: SwiftUI.Text) -> SwiftUI.Text {
        styles.reduce(text) { result, style in
            style.apply(to: result)
        }
    }
}

// MARK: - TextStyleBuilder

@resultBuilder
public struct TextStyleBuilder {
    public static func buildBlock(_ components: any TextStyle...) -> CompositeTextStyle {
        CompositeTextStyle(components)
    }

    public static func buildOptional(_ component: (any TextStyle)?) -> any TextStyle {
        if let component { return component }
        return CompositeTextStyle([])
    }

    public static func buildEither(first component: any TextStyle) -> any TextStyle {
        component
    }

    public static func buildEither(second component: any TextStyle) -> any TextStyle {
        component
    }

    public static func buildArray(_ components: [any TextStyle]) -> any TextStyle {
        CompositeTextStyle(components)
    }

    public static func buildExpression(_ expression: any TextStyle) -> any TextStyle {
        expression
    }
}

// MARK: - Text Extension

extension SwiftUI.Text {
    public func styled(with style: any TextStyle) -> SwiftUI.Text {
        style.apply(to: self)
    }

    public func styled(@TextStyleBuilder _ builder: () -> CompositeTextStyle) -> SwiftUI.Text {
        builder().apply(to: self)
    }
}
