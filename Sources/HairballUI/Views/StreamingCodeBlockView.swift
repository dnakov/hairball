import SwiftUI
import Hairball

/// Code block view with streaming reveal support.
/// Stateless — receives `revealPosition` from the parent's single cursor.
struct StreamingCodeBlockView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeSyntaxHighlighter) private var highlighter
    @Environment(\.tokenAnimator) private var animator
    @State private var isCopied = false

    let language: String?
    let content: String
    let revealPosition: Double

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
                codeText
                    .font(theme.codeBlock.font)
                    .foregroundColor(theme.codeBlock.textColor)
                    .padding(theme.codeBlock.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
    }

    @ViewBuilder
    private var codeText: some View {
        let highlighted = highlighter.highlightCode(trimmedContent, language: language)
        let totalCount = highlighted.characters.count
        let splitAt = max(min(Int(revealPosition), totalCount), 0)
        let frac = revealPosition - Double(splitAt)
        let caughtUp = splitAt >= totalCount
        let parts = highlighted.split(at: splitAt)

        animator.animate(
            revealed: parts.before,
            fresh: caughtUp ? AttributedString() : parts.after.prefix(1),
            progress: caughtUp ? 1.0 : frac,
            foregroundColor: theme.codeBlock.textColor
        )
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
