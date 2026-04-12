import SwiftUI
import Hairball

/// Code block with streaming reveal. Uses `RevealedText` for the code content.

struct StreamingCodeBlockView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeSyntaxHighlighter) private var highlighter
    @State private var isCopied = false

    let language: String?
    let content: String
    let revealPosition: Double
    let blockComplete: Bool

    init(language: String?, content: String, revealPosition: Double, blockComplete: Bool = true) {
        self.language = language
        self.content = content
        self.revealPosition = revealPosition
        self.blockComplete = blockComplete
    }

    private var trimmedContent: String {
        content.hasSuffix("\n") ? String(content.dropLast()) : content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if theme.codeBlock.showLanguageLabel || theme.codeBlock.showCopyButton {
                CodeBlockHeaderBar(language: language, isCopied: isCopied) {
                    copyToClipboard()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                RevealedText(
                    attributedString: highlighter.highlightCode(trimmedContent, language: language),
                    revealPosition: revealPosition,
                    blockComplete: blockComplete
                )
                .font(theme.codeBlock.font)
                .foregroundColor(theme.codeBlock.textColor)
                .padding(theme.codeBlock.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
        withAnimation { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isCopied = false }
        }
    }
}

// MARK: - Shared Code Block Header

struct CodeBlockHeaderBar: View {
    @Environment(\.markdownTheme) private var theme
    let language: String?
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack {
            if theme.codeBlock.showLanguageLabel, let language, !language.isEmpty {
                SwiftUI.Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            if theme.codeBlock.showCopyButton {
                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        if isCopied { SwiftUI.Text("Copied") }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
