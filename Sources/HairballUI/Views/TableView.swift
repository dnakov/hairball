import SwiftUI
import Hairball

public struct MarkdownTableView: View {
    @Environment(\.markdownTheme) private var theme

    private let columnAlignments: [MarkdownTableColumnAlignment]
    private let head: MarkdownTableRow
    private let body_: [MarkdownTableRow]

    public init(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow]) {
        self.columnAlignments = columnAlignments
        self.head = head
        self.body_ = body
    }

    private var colCount: Int {
        max(
            1,
            columnAlignments.count,
            head.cells.count,
            body_.map(\.cells.count).max() ?? 0
        )
    }
    private var style: TableStyle { theme.table }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                rowView(for: head, isHeader: true)
                    .background(style.headerBackground)

                Rectangle()
                    .fill(style.borderColor)
                    .frame(height: max(style.borderWidth, 1))

                ForEach(Array(body_.enumerated()), id: \.offset) { rowIndex, row in
                    rowView(for: row, isHeader: false)
                    .background(rowBackground(rowIndex: rowIndex))

                    if rowIndex < body_.count - 1 && style.borderWidth > 0 {
                        Rectangle()
                            .fill(style.borderColor)
                            .frame(height: style.borderWidth)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .strokeBorder(style.borderColor, lineWidth: style.borderWidth)
            )
        }
    }

    private func rowView(for row: MarkdownTableRow, isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<colCount, id: \.self) { col in
                cellView(for: row, col: col, isHeader: isHeader)
            }
        }
    }

    @ViewBuilder
    private func cellView(for row: MarkdownTableRow, col: Int, isHeader: Bool) -> some View {
        let cell = col < row.cells.count ? row.cells[col] : MarkdownTableCell(content: [])
        let renderer = InlineTextRenderer(theme: theme)
        let rendered = renderer.render(
            cell.content,
            baseStyle: InlineStyle(
                font: theme.bodyFont,
                fontWeight: isHeader ? style.headerFontWeight : nil,
                foregroundColor: theme.bodyTextColor
            )
        )
        let align = alignment(for: col)

        VStack(alignment: horizontalAlignment(for: col), spacing: 0) {
            rendered
                .multilineTextAlignment(textAlignment(for: col))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textSelection(.enabled)
        .frame(
            width: columnContentWidth,
            alignment: align
        )
        .padding(.horizontal, style.cellConfiguration.horizontalPadding)
        .padding(.vertical, style.cellConfiguration.verticalPadding)
        .frame(width: columnVisualWidth, alignment: align)
    }

    private func alignment(for col: Int) -> Alignment {
        guard col < columnAlignments.count else { return .leading }
        switch columnAlignments[col] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func horizontalAlignment(for col: Int) -> HorizontalAlignment {
        guard col < columnAlignments.count else { return .leading }
        switch columnAlignments[col] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func textAlignment(for col: Int) -> TextAlignment {
        guard col < columnAlignments.count else { return .leading }
        switch columnAlignments[col] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var columnContentWidth: CGFloat {
        max(
            style.minimumColumnWidth,
            columnVisualWidth - style.cellConfiguration.horizontalPadding * 2
        )
    }

    private var columnVisualWidth: CGFloat {
        switch colCount {
        case 0...2:
            return style.maximumColumnWidth
        case 3:
            return min(style.maximumColumnWidth, 260)
        default:
            return min(style.maximumColumnWidth, 220)
        }
    }

    private func rowBackground(rowIndex: Int) -> Color {
        switch style.backgroundStyle {
        case .none:
            return .clear
        case .color(let color):
            return color
        case .alternatingRows(let even, let odd):
            return rowIndex.isMultiple(of: 2) ? even : odd
        }
    }
}
