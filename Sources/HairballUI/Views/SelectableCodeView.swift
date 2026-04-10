import SwiftUI
import Hairball

/// A code view that supports text selection.
/// Matches the `SelectableCodeView` found in the original binary.
public struct SelectableCodeView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeSyntaxHighlighter) private var highlighter

    private let code: String
    private let language: String?

    public init(code: String, language: String? = nil) {
        self.code = code
        self.language = language
    }

    public var body: some View {
        let highlighted = highlighter.highlightCode(code, language: language)

        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            SwiftUI.Text(highlighted)
                .font(theme.codeBlock.font)
                .foregroundColor(theme.codeBlock.textColor)
                .textSelection(.enabled)
                .padding(theme.codeBlock.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
    }
}

/// A plain text preview - renders raw text without syntax highlighting.
/// Matches the `PlainTextPreviewView` from the original binary.
public struct PlainTextPreviewView: View {
    @Environment(\.markdownTheme) private var theme

    private let text: String
    private let maxLines: Int?

    public init(_ text: String, maxLines: Int? = nil) {
        self.text = text
        self.maxLines = maxLines
    }

    public var body: some View {
        SwiftUI.Text(text)
            .font(theme.codeBlock.font)
            .foregroundColor(theme.bodyTextColor)
            .lineLimit(maxLines)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
