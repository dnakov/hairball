import SwiftUI
import Hairball

public struct CodeBlockView: View, Equatable {
    private let language: String?
    private let content: String
    private let isSmall: Bool

    public init(language: String?, content: String, isSmall: Bool = false) {
        self.language = language
        self.content = content
        self.isSmall = isSmall
    }

    public static func == (lhs: CodeBlockView, rhs: CodeBlockView) -> Bool {
        lhs.language == rhs.language && lhs.content == rhs.content && lhs.isSmall == rhs.isSmall
    }

    public var body: some View {
        CodeBlockBody(language: language, content: content, isSmall: isSmall)
    }
}

private struct CodeBlockBody: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeSyntaxHighlighter) private var highlighter
    @State private var isCopied = false

    let language: String?
    let content: String
    let isSmall: Bool

    private var trimmedContent: String {
        content.hasSuffix("\n") ? String(content.dropLast()) : content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if theme.codeBlock.showLanguageLabel || theme.codeBlock.showCopyButton {
                headerBar
            }

            ScrollView(.horizontal, showsIndicators: false) {
                SwiftUI.Text(highlighter.highlightCode(trimmedContent, language: language))
                    .font(isSmall ? .system(.caption, design: .monospaced) : theme.codeBlock.font)
                    .foregroundColor(theme.codeBlock.textColor)
                    .padding(isSmall
                        ? EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                        : theme.codeBlock.padding
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
    }

    @ViewBuilder
    private var headerBar: some View {
        CodeBlockHeaderBar(language: language, isCopied: isCopied) {
            copyToClipboard()
        }
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif

        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}
