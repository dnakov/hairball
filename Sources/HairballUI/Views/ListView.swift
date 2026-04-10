import SwiftUI
import Hairball

// MARK: - Ordered List

public struct OrderedListView: View {
    @Environment(\.markdownTheme) private var theme

    private let startIndex: Int
    private let tight: Bool
    private let items: [ListItem]

    public init(startIndex: Int, tight: Bool, items: [ListItem]) {
        self.startIndex = startIndex
        self.tight = tight
        self.items = items
    }

    public var body: some View {
        let spacing = tight ? theme.list.tightItemSpacing : theme.list.itemSpacing

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                ListItemView(
                    marker: .ordered(startIndex + index),
                    item: item,
                    tight: tight
                )
            }
        }
    }
}

// MARK: - Unordered List

public struct UnorderedListView: View {
    @Environment(\.markdownTheme) private var theme

    private let tight: Bool
    private let items: [ListItem]

    public init(tight: Bool, items: [ListItem]) {
        self.tight = tight
        self.items = items
    }

    public var body: some View {
        let spacing = tight ? theme.list.tightItemSpacing : theme.list.itemSpacing

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ListItemView(
                    marker: item.checkbox != nil ? .checkbox(item.checkbox!) : .unordered,
                    item: item,
                    tight: tight
                )
            }
        }
    }
}

// MARK: - List Item

enum ListMarker {
    case ordered(Int)
    case unordered
    case checkbox(CheckboxState)
}

struct ListItemView: View {
    @Environment(\.markdownTheme) private var theme

    let marker: ListMarker
    let item: ListItem
    let tight: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            markerView
                .frame(minWidth: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: tight ? theme.list.tightItemSpacing : theme.list.itemSpacing) {
                ForEach(Array(item.children.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                }
            }
        }
        .padding(.leading, theme.list.indentWidth > 20 ? theme.list.indentWidth - 20 : 0)
    }

    @ViewBuilder
    private var markerView: some View {
        switch marker {
        case .ordered(let number):
            Text("\(number).")
                .font(theme.bodyFont)
                .foregroundColor(theme.bodyTextColor)
        case .unordered:
            Text(theme.list.bulletMarker.text)
                .font(theme.bodyFont)
                .foregroundColor(theme.bodyTextColor)
        case .checkbox(let state):
            Image(systemName: state == .checked
                ? theme.list.checkboxCheckedSymbol
                : theme.list.checkboxUncheckedSymbol)
                .font(theme.bodyFont)
                .foregroundColor(state == .checked ? .accentColor : .secondary)
        }
    }
}
