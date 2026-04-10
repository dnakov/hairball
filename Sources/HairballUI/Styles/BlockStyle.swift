import SwiftUI
import Hairball

// MARK: - BlockStyle Protocol

public protocol BlockStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(content: BlockStyleContent) -> Body
}

public struct BlockStyleContent {
    public let blockNode: BlockNode
    public let label: AnyView

    public init(blockNode: BlockNode, label: AnyView) {
        self.blockNode = blockNode
        self.label = label
    }
}

// MARK: - DefaultBlockStyle

public struct DefaultBlockStyle: BlockStyle {
    public init() {}

    public func makeBody(content: BlockStyleContent) -> some View {
        content.label
    }
}

// MARK: - Type-erased wrapper

public struct AnyBlockStyle: BlockStyle {
    private let _makeBody: (BlockStyleContent) -> AnyView

    public init<S: BlockStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(content: $0)) }
    }

    public func makeBody(content: BlockStyleContent) -> some View {
        _makeBody(content)
    }
}

// MARK: - Block Style Modifiers

public struct PaddedBlockStyle: BlockStyle {
    let edges: Edge.Set
    let length: CGFloat?

    public init(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) {
        self.edges = edges
        self.length = length
    }

    public func makeBody(content: BlockStyleContent) -> some View {
        content.label.padding(edges, length)
    }
}

public struct BackgroundBlockStyle: BlockStyle {
    let color: Color
    let cornerRadius: CGFloat

    public init(color: Color, cornerRadius: CGFloat = 0) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    public func makeBody(content: BlockStyleContent) -> some View {
        content.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
            )
    }
}

public struct BorderedBlockStyle: BlockStyle {
    let edges: Edge.Set
    let color: Color
    let width: CGFloat

    public init(edges: Edge.Set = .all, color: Color, width: CGFloat = 1) {
        self.edges = edges
        self.color = color
        self.width = width
    }

    public func makeBody(content: BlockStyleContent) -> some View {
        content.label
            .overlay(
                BlockBorderShape(edges: edges)
                    .stroke(color, lineWidth: width)
            )
    }
}

private struct BlockBorderShape: Shape {
    let edges: Edge.Set

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if edges.contains(.top) {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        if edges.contains(.bottom) {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        if edges.contains(.leading) {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        if edges.contains(.trailing) {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return path
    }
}

// MARK: - View Extensions for Block Styling

extension View {
    public func blockStyle(_ style: some BlockStyle, for block: BlockNode) -> some View {
        let content = BlockStyleContent(blockNode: block, label: AnyView(self))
        return style.makeBody(content: content)
    }

    public func codeBlockStyle(theme: MarkdownTheme) -> some View {
        self
            .padding(theme.codeBlock.padding)
            .background(
                RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius)
                    .fill(theme.codeBlock.backgroundColor)
            )
    }

    public func blockquoteStyle(theme: MarkdownTheme) -> some View {
        self
            .foregroundColor(theme.blockquote.textColor)
            .padding(.leading, theme.blockquote.leadingPadding)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(theme.blockquote.borderColor)
                    .frame(width: theme.blockquote.borderWidth)
            }
    }

    public func thematicBreakStyle(theme: MarkdownTheme) -> some View {
        Rectangle()
            .fill(theme.thematicBreak.color)
            .frame(height: theme.thematicBreak.height)
            .padding(.vertical, theme.thematicBreak.verticalMargin)
    }
}
