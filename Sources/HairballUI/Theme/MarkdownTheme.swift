import SwiftUI

// MARK: - Heading Style

public struct HeadingStyle: Sendable, Equatable {
    public var font: Font
    public var fontSize: CGFloat
    public var weight: Font.Weight
    public var topSpacing: CGFloat
    public var bottomSpacing: CGFloat
    public var color: Color

    public init(
        font: Font? = nil,
        fontSize: CGFloat = 14,
        weight: Font.Weight = .bold,
        topSpacing: CGFloat = 8,
        bottomSpacing: CGFloat = 4,
        color: Color = .primary
    ) {
        self.font = font ?? .system(size: fontSize, weight: weight)
        self.fontSize = fontSize
        self.weight = weight
        self.topSpacing = topSpacing
        self.bottomSpacing = bottomSpacing
        self.color = color
    }
}

// MARK: - Heading Style Set

public struct HeadingStyleSet: Sendable, Equatable {
    public var h1: HeadingStyle
    public var h2: HeadingStyle
    public var h3: HeadingStyle
    public var h4: HeadingStyle
    public var h5: HeadingStyle
    public var h6: HeadingStyle

    public init(
        h1: HeadingStyle = HeadingStyle(fontSize: 24, weight: .bold, topSpacing: 0, bottomSpacing: 16),
        h2: HeadingStyle = HeadingStyle(fontSize: 20, weight: .bold, topSpacing: 24, bottomSpacing: 12),
        h3: HeadingStyle = HeadingStyle(fontSize: 16, weight: .semibold, topSpacing: 20, bottomSpacing: 8),
        h4: HeadingStyle = HeadingStyle(fontSize: 14, weight: .semibold, topSpacing: 16, bottomSpacing: 6),
        h5: HeadingStyle = HeadingStyle(fontSize: 13, weight: .semibold, topSpacing: 12, bottomSpacing: 4),
        h6: HeadingStyle = HeadingStyle(fontSize: 12, weight: .semibold, topSpacing: 12, bottomSpacing: 4)
    ) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.h5 = h5
        self.h6 = h6
    }

    public subscript(level: Int) -> HeadingStyle {
        switch level {
        case 1: return h1
        case 2: return h2
        case 3: return h3
        case 4: return h4
        case 5: return h5
        default: return h6
        }
    }

    public var asDictionary: [Int: HeadingStyle] {
        [1: h1, 2: h2, 3: h3, 4: h4, 5: h5, 6: h6]
    }
}

// MARK: - Code Block Style

public struct CodeBlockStyle: Sendable, Equatable {
    public var backgroundColor: Color
    public var textColor: Color
    public var font: Font
    public var fontSize: CGFloat
    public var cornerRadius: CGFloat
    public var padding: EdgeInsets
    public var showLanguageLabel: Bool
    public var showCopyButton: Bool

    public init(
        backgroundColor: Color = Color(red: 0.96, green: 0.96, blue: 0.96),
        textColor: Color = .primary,
        font: Font = .system(size: 12, design: .monospaced),
        fontSize: CGFloat = 12,
        cornerRadius: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        showLanguageLabel: Bool = true,
        showCopyButton: Bool = true
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.fontSize = fontSize
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showLanguageLabel = showLanguageLabel
        self.showCopyButton = showCopyButton
    }
}

// MARK: - Inline Code Style

public struct InlineCodeStyle: Sendable, Equatable {
    public var backgroundColor: Color
    public var textColor: Color
    public var font: Font
    public var fontSize: CGFloat
    public var cornerRadius: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat

    /// EdgeInsets computed from horizontal/vertical padding for convenience.
    public var padding: EdgeInsets {
        EdgeInsets(top: verticalPadding, leading: horizontalPadding, bottom: verticalPadding, trailing: horizontalPadding)
    }

    public init(
        backgroundColor: Color = Color(red: 0.94, green: 0.94, blue: 0.94),
        textColor: Color = .primary,
        font: Font = .system(size: 12, design: .monospaced),
        fontSize: CGFloat = 12,
        cornerRadius: CGFloat = 2,
        horizontalPadding: CGFloat = 4,
        verticalPadding: CGFloat = 2
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.fontSize = fontSize
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
}

// MARK: - Blockquote Style

public struct BlockquoteStyle: Sendable, Equatable {
    public var borderColor: Color
    public var borderWidth: CGFloat
    public var backgroundColor: Color
    public var textColor: Color
    public var padding: EdgeInsets

    public var leadingPadding: CGFloat { padding.leading }

    public init(
        borderColor: Color = .accentColor,
        borderWidth: CGFloat = 3,
        backgroundColor: Color = .clear,
        textColor: Color = .secondary,
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 4)
    ) {
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.padding = padding
    }
}

// MARK: - Table Styles

public enum TableBackgroundStyle: Sendable, Equatable {
    case none
    case color(Color)
    case alternatingRows(even: Color, odd: Color)
}

public enum TableBorderStyle: Sendable, Equatable {
    case none
    case solid(color: Color, width: CGFloat)
}

public struct TableCellConfiguration: Sendable, Equatable {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat

    public init(horizontalPadding: CGFloat = 12, verticalPadding: CGFloat = 8) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
}

public struct TableStyle: Sendable, Equatable {
    public var borderStyle: TableBorderStyle
    public var headerBackground: Color
    public var headerFontWeight: Font.Weight
    public var backgroundStyle: TableBackgroundStyle
    public var cellConfiguration: TableCellConfiguration
    public var fontSize: CGFloat
    public var verticalMargin: CGFloat
    public var cornerRadius: CGFloat

    /// Convenience accessors for backward compatibility.
    public var headerBackgroundColor: Color { headerBackground }
    public var headerTextColor: Color { .primary }
    public var alternatingRowColor: Color {
        switch backgroundStyle {
        case .alternatingRows(_, let odd): return odd
        case .color(let c): return c
        case .none: return .clear
        }
    }
    public var borderColor: Color {
        switch borderStyle {
        case .solid(let color, _): return color
        case .none: return .clear
        }
    }
    public var borderWidth: CGFloat {
        switch borderStyle {
        case .solid(_, let width): return width
        case .none: return 0
        }
    }
    public var cellPadding: EdgeInsets {
        EdgeInsets(
            top: cellConfiguration.verticalPadding,
            leading: cellConfiguration.horizontalPadding,
            bottom: cellConfiguration.verticalPadding,
            trailing: cellConfiguration.horizontalPadding
        )
    }

    public init(
        borderStyle: TableBorderStyle = .solid(color: Color(red: 0.87, green: 0.87, blue: 0.87), width: 1),
        headerBackground: Color = Color(red: 0.96, green: 0.96, blue: 0.96),
        headerFontWeight: Font.Weight = .semibold,
        backgroundStyle: TableBackgroundStyle = .alternatingRows(
            even: Color(red: 0.98, green: 0.98, blue: 0.98),
            odd: .clear
        ),
        cellConfiguration: TableCellConfiguration = TableCellConfiguration(),
        fontSize: CGFloat = 13,
        verticalMargin: CGFloat = 16,
        cornerRadius: CGFloat = 0
    ) {
        self.borderStyle = borderStyle
        self.headerBackground = headerBackground
        self.headerFontWeight = headerFontWeight
        self.backgroundStyle = backgroundStyle
        self.cellConfiguration = cellConfiguration
        self.fontSize = fontSize
        self.verticalMargin = verticalMargin
        self.cornerRadius = cornerRadius
    }
}

// MARK: - Thematic Break Style

public struct ThematicBreakStyle: Sendable, Equatable {
    public var color: Color
    public var height: CGFloat
    public var verticalPadding: CGFloat

    public var verticalMargin: CGFloat { verticalPadding }

    public init(
        color: Color = Color.gray.opacity(0.4),
        height: CGFloat = 1,
        verticalPadding: CGFloat = 12
    ) {
        self.color = color
        self.height = height
        self.verticalPadding = verticalPadding
    }
}

// MARK: - List Style Configuration

public enum UnorderedListMarker: Sendable, Equatable {
    case bullet
    case dash
    case custom(String)

    var text: String {
        switch self {
        case .bullet: return "\u{2022}"
        case .dash: return "-"
        case .custom(let s): return s
        }
    }
}

public struct ListStyleConfiguration: Sendable, Equatable {
    public var bulletMarker: UnorderedListMarker
    public var indentWidth: CGFloat
    public var itemSpacing: CGFloat
    public var tightItemSpacing: CGFloat
    public var verticalMargin: CGFloat
    public var checkboxCheckedSymbol: String
    public var checkboxUncheckedSymbol: String
    public var orderedNumeralTrailing: String

    public init(
        bulletMarker: UnorderedListMarker = .bullet,
        indentWidth: CGFloat = 24,
        itemSpacing: CGFloat = 4,
        tightItemSpacing: CGFloat = 2,
        verticalMargin: CGFloat = 12,
        checkboxCheckedSymbol: String = "checkmark.square.fill",
        checkboxUncheckedSymbol: String = "square",
        orderedNumeralTrailing: String = "."
    ) {
        self.bulletMarker = bulletMarker
        self.indentWidth = indentWidth
        self.itemSpacing = itemSpacing
        self.tightItemSpacing = tightItemSpacing
        self.verticalMargin = verticalMargin
        self.checkboxCheckedSymbol = checkboxCheckedSymbol
        self.checkboxUncheckedSymbol = checkboxUncheckedSymbol
        self.orderedNumeralTrailing = orderedNumeralTrailing
    }
}

// MARK: - Link Style

public struct LinkStyle: Sendable, Equatable {
    public var color: Color
    public var underline: Bool

    public init(
        color: Color = .accentColor,
        underline: Bool = true
    ) {
        self.color = color
        self.underline = underline
    }
}

// MARK: - Citation Style

public struct CitationStyle: Sendable, Equatable {
    public var height: CGFloat
    public var maxWidth: CGFloat
    public var horizontalPadding: CGFloat
    public var fontSize: CGFloat
    public var textColor: Color
    public var backgroundColor: Color
    public var borderColor: Color
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat
    public var horizontalMargin: CGFloat

    public init(
        height: CGFloat = 18,
        maxWidth: CGFloat = 180,
        horizontalPadding: CGFloat = 6,
        fontSize: CGFloat = 11,
        textColor: Color = Color(red: 0.4, green: 0.4, blue: 0.4),
        backgroundColor: Color = Color(red: 0.96, green: 0.96, blue: 0.96),
        borderColor: Color = Color(red: 0.87, green: 0.87, blue: 0.87),
        borderWidth: CGFloat = 0.5,
        cornerRadius: CGFloat = 9,
        horizontalMargin: CGFloat = 2
    ) {
        self.height = height
        self.maxWidth = maxWidth
        self.horizontalPadding = horizontalPadding
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.horizontalMargin = horizontalMargin
    }
}

// MARK: - Soft Break Mode

public enum SoftBreakMode: Sendable, Equatable {
    case space
    case lineBreak
}

// MARK: - MarkdownTheme

public struct MarkdownTheme: Sendable, Equatable {
    public var bodyFont: Font
    public var bodyFontSize: CGFloat
    public var foregroundColor: Color
    public var lineSpacing: CGFloat
    public var paragraphSpacing: CGFloat
    public var blockSpacing: CGFloat
    public var softBreakMode: SoftBreakMode

    public var headingStyleSet: HeadingStyleSet
    public var codeBlock: CodeBlockStyle
    public var inlineCode: InlineCodeStyle
    public var blockquote: BlockquoteStyle
    public var table: TableStyle
    public var thematicBreak: ThematicBreakStyle
    public var link: LinkStyle
    public var list: ListStyleConfiguration
    public var citation: CitationStyle

    // Heading spacing multipliers (from binary analysis)
    public var headingTopSpacingMultiplier: CGFloat
    public var headingBottomSpacingMultiplier: CGFloat

    /// Backward-compatible aliases.
    public var bodyTextColor: Color {
        get { foregroundColor }
        set { foregroundColor = newValue }
    }
    public var tintColor: Color {
        get { link.color }
        set { link.color = newValue }
    }

    /// Dictionary-based heading style access.
    public var headingStyles: [Int: HeadingStyle] {
        get { headingStyleSet.asDictionary }
        set {
            if let s = newValue[1] { headingStyleSet.h1 = s }
            if let s = newValue[2] { headingStyleSet.h2 = s }
            if let s = newValue[3] { headingStyleSet.h3 = s }
            if let s = newValue[4] { headingStyleSet.h4 = s }
            if let s = newValue[5] { headingStyleSet.h5 = s }
            if let s = newValue[6] { headingStyleSet.h6 = s }
        }
    }

    public init(
        bodyFont: Font = .system(size: 14),
        bodyFontSize: CGFloat = 14,
        foregroundColor: Color = .primary,
        lineSpacing: CGFloat = 1.6,
        paragraphSpacing: CGFloat = 12,
        blockSpacing: CGFloat = 12,
        softBreakMode: SoftBreakMode = .space,
        headingStyleSet: HeadingStyleSet = HeadingStyleSet(),
        headingStyles: [Int: HeadingStyle]? = nil,
        codeBlock: CodeBlockStyle = CodeBlockStyle(),
        inlineCode: InlineCodeStyle = InlineCodeStyle(),
        blockquote: BlockquoteStyle = BlockquoteStyle(),
        table: TableStyle = TableStyle(),
        thematicBreak: ThematicBreakStyle = ThematicBreakStyle(),
        link: LinkStyle = LinkStyle(),
        list: ListStyleConfiguration = ListStyleConfiguration(),
        citation: CitationStyle = CitationStyle(),
        headingTopSpacingMultiplier: CGFloat = 1.0,
        headingBottomSpacingMultiplier: CGFloat = 1.0
    ) {
        self.bodyFont = bodyFont
        self.bodyFontSize = bodyFontSize
        self.foregroundColor = foregroundColor
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.blockSpacing = blockSpacing
        self.softBreakMode = softBreakMode
        self.headingStyleSet = headingStyleSet
        self.codeBlock = codeBlock
        self.inlineCode = inlineCode
        self.blockquote = blockquote
        self.table = table
        self.thematicBreak = thematicBreak
        self.link = link
        self.list = list
        self.citation = citation
        self.headingTopSpacingMultiplier = headingTopSpacingMultiplier
        self.headingBottomSpacingMultiplier = headingBottomSpacingMultiplier

        // Apply dictionary overrides if provided
        if let headingStyles {
            if let s = headingStyles[1] { self.headingStyleSet.h1 = s }
            if let s = headingStyles[2] { self.headingStyleSet.h2 = s }
            if let s = headingStyles[3] { self.headingStyleSet.h3 = s }
            if let s = headingStyles[4] { self.headingStyleSet.h4 = s }
            if let s = headingStyles[5] { self.headingStyleSet.h5 = s }
            if let s = headingStyles[6] { self.headingStyleSet.h6 = s }
        }
    }

    public func headingStyle(for level: Int) -> HeadingStyle {
        headingStyleSet[level]
    }
}

// MARK: - Manual Equatable (Font does not conform to Equatable)

extension HeadingStyle {
    public static func == (lhs: HeadingStyle, rhs: HeadingStyle) -> Bool {
        lhs.fontSize == rhs.fontSize &&
        lhs.weight == rhs.weight &&
        lhs.topSpacing == rhs.topSpacing &&
        lhs.bottomSpacing == rhs.bottomSpacing &&
        lhs.color == rhs.color
    }
}

extension CodeBlockStyle {
    public static func == (lhs: CodeBlockStyle, rhs: CodeBlockStyle) -> Bool {
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.textColor == rhs.textColor &&
        lhs.fontSize == rhs.fontSize &&
        lhs.cornerRadius == rhs.cornerRadius &&
        lhs.padding == rhs.padding &&
        lhs.showLanguageLabel == rhs.showLanguageLabel &&
        lhs.showCopyButton == rhs.showCopyButton
    }
}

extension InlineCodeStyle {
    public static func == (lhs: InlineCodeStyle, rhs: InlineCodeStyle) -> Bool {
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.textColor == rhs.textColor &&
        lhs.fontSize == rhs.fontSize &&
        lhs.cornerRadius == rhs.cornerRadius &&
        lhs.horizontalPadding == rhs.horizontalPadding &&
        lhs.verticalPadding == rhs.verticalPadding
    }
}

extension MarkdownTheme {
    public static func == (lhs: MarkdownTheme, rhs: MarkdownTheme) -> Bool {
        lhs.bodyFontSize == rhs.bodyFontSize &&
        lhs.foregroundColor == rhs.foregroundColor &&
        lhs.lineSpacing == rhs.lineSpacing &&
        lhs.paragraphSpacing == rhs.paragraphSpacing &&
        lhs.blockSpacing == rhs.blockSpacing &&
        lhs.softBreakMode == rhs.softBreakMode &&
        lhs.headingStyleSet == rhs.headingStyleSet &&
        lhs.codeBlock == rhs.codeBlock &&
        lhs.inlineCode == rhs.inlineCode &&
        lhs.blockquote == rhs.blockquote &&
        lhs.table == rhs.table &&
        lhs.thematicBreak == rhs.thematicBreak &&
        lhs.link == rhs.link &&
        lhs.list == rhs.list &&
        lhs.citation == rhs.citation &&
        lhs.headingTopSpacingMultiplier == rhs.headingTopSpacingMultiplier &&
        lhs.headingBottomSpacingMultiplier == rhs.headingBottomSpacingMultiplier
    }
}

// MARK: - Preset Themes

extension MarkdownTheme {
    /// The default markdown theme, matching the extracted CSS.
    public static let `default` = MarkdownTheme()

    /// Theme for assistant chat bubbles (light background, dark text).
    public static let assistantBubble = MarkdownTheme(
        bodyFont: .system(size: 15),
        bodyFontSize: 15,
        foregroundColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        paragraphSpacing: 10,
        blockSpacing: 10,
        codeBlock: CodeBlockStyle(
            backgroundColor: Color(red: 0.88, green: 0.88, blue: 0.9),
            textColor: Color(red: 0.1, green: 0.1, blue: 0.1)
        ),
        blockquote: BlockquoteStyle(
            borderColor: Color(red: 0.7, green: 0.7, blue: 0.75),
            textColor: Color(red: 0.35, green: 0.35, blue: 0.35)
        ),
        link: LinkStyle(color: Color(red: 0.0, green: 0.4, blue: 0.8))
    )

    /// Theme for user chat bubbles.
    public static let userBubble = MarkdownTheme(
        bodyFont: .system(size: 15),
        bodyFontSize: 15,
        foregroundColor: .white,
        paragraphSpacing: 8,
        blockSpacing: 8,
        codeBlock: CodeBlockStyle(
            backgroundColor: Color.white.opacity(0.15),
            font: .system(size: 12, design: .monospaced),
            fontSize: 12,
            cornerRadius: 6,
            padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        ),
        inlineCode: InlineCodeStyle(
            backgroundColor: Color.white.opacity(0.15),
            font: .system(size: 12, design: .monospaced),
            fontSize: 12
        ),
        blockquote: BlockquoteStyle(
            borderColor: Color.white.opacity(0.4),
            textColor: Color.white.opacity(0.8)
        ),
        link: LinkStyle(color: .white)
    )

    /// Theme for user chat bubbles in pending state.
    public static let userBubblePending: MarkdownTheme = {
        var theme = userBubble
        theme.foregroundColor = Color.white.opacity(0.6)
        return theme
    }()
}

// MARK: - Environment Key

private struct MarkdownThemeKey: EnvironmentKey {
    static let defaultValue = MarkdownTheme.default
}

extension EnvironmentValues {
    public var markdownTheme: MarkdownTheme {
        get { self[MarkdownThemeKey.self] }
        set { self[MarkdownThemeKey.self] = newValue }
    }
}

extension View {
    public func markdownTheme(_ theme: MarkdownTheme) -> some View {
        environment(\.markdownTheme, theme)
            .environment(\.softBreakMode, theme.softBreakMode)
    }
}

// MARK: - SoftBreakMode Environment Key

private struct SoftBreakModeKey: EnvironmentKey {
    static let defaultValue: SoftBreakMode = .space
}

extension EnvironmentValues {
    public var softBreakMode: SoftBreakMode {
        get { self[SoftBreakModeKey.self] }
        set { self[SoftBreakModeKey.self] = newValue }
    }
}
