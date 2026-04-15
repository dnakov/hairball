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

    private var colCount: Int { columnAlignments.count }
    private var style: TableStyle { theme.table }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header
                GridRow {
                    ForEach(0..<colCount, id: \.self) { col in
                        cellView(for: head, col: col, isHeader: true)
                    }
                }
                .background(style.headerBackground)

                // Header border
                GridRow {
                    Rectangle()
                        .fill(style.borderColor)
                        .frame(height: max(style.borderWidth, 1))
                        .gridCellColumns(colCount)
                }

                // Body rows
                ForEach(Array(body_.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<colCount, id: \.self) { col in
                            cellView(for: row, col: col, isHeader: false)
                        }
                    }
                    .background(rowBackground(rowIndex: rowIndex))

                    if rowIndex < body_.count - 1 && style.borderWidth > 0 {
                        GridRow {
                            Rectangle()
                                .fill(style.borderColor)
                                .frame(height: style.borderWidth)
                                .gridCellColumns(colCount)
                        }
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

        Group {
            rendered
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: align)
        .padding(.horizontal, style.cellConfiguration.horizontalPadding)
        .padding(.vertical, style.cellConfiguration.verticalPadding)
        .gridColumnAlignment(horizontalAlignment(for: col))
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
