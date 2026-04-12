import SwiftUI
import Hairball

// MARK: - List Marker

enum ListMarker {
    case ordered(Int)
    case unordered
    case checkbox(CheckboxState)
}

// MARK: - List Item Container

/// The visual layout for a list item — marker + content side by side.
/// Used by both `ListItemView` (normal) and cursor reveal (streaming).
struct ListItemContainer<Content: View>: View {
    @Environment(\.markdownTheme) private var theme
    let marker: ListMarker
    let content: Content

    init(marker: ListMarker, @ViewBuilder content: () -> Content) {
        self.marker = marker
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            markerView
                .frame(minWidth: 20, alignment: .trailing)
            content
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

// MARK: - List Item Children

/// Shared children stack for list items — renders block children in a VStack.
private struct ListItemChildrenStack: View {
    @Environment(\.markdownTheme) private var theme
    let item: ListItem
    let tight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tight ? theme.list.tightItemSpacing : theme.list.itemSpacing) {
            ForEach(Array(item.children.enumerated()), id: \.offset) { _, block in
                BlockNodeView(node: block)
            }
        }
    }
}

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
                ListItemContainer(marker: .ordered(startIndex + index)) {
                    ListItemChildrenStack(item: item, tight: tight)
                }
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
                let marker: ListMarker = item.checkbox != nil
                    ? .checkbox(item.checkbox!)
                    : .unordered
                ListItemContainer(marker: marker) {
                    ListItemChildrenStack(item: item, tight: tight)
                }
            }
        }
    }
}
