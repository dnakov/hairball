import SwiftUI
import Hairball

/// Code block view with streaming reveal support.
/// Uses the same `SmoothRevealDriver` / `TokenAnimator` system as `StreamingTextView`.
struct StreamingCodeBlockView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeSyntaxHighlighter) private var highlighter
    @Environment(\.tokenRevealConfig) private var revealConfig
    @Environment(\.tokenAnimator) private var animator
    @StateObject private var revealDriver = SmoothRevealDriver()
    @State private var isCopied = false
    @State private var cachedHighlight: AttributedString?
    @State private var cachedContent: String = ""

    let language: String?
    let content: String
    let isStreaming: Bool

    private var trimmedContent: String {
        content.hasSuffix("\n") ? String(content.dropLast()) : content
    }

    /// Highlighted code, cached to avoid re-highlighting every frame.
    private var highlighted: AttributedString {
        let text = trimmedContent
        if text == cachedContent, let cached = cachedHighlight {
            return cached
        }
        return highlighter.highlightCode(text, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if theme.codeBlock.showLanguageLabel || theme.codeBlock.showCopyButton {
                CodeBlockHeaderBar(language: language, isCopied: isCopied) {
                    copyToClipboard()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                codeContent
                    .font(theme.codeBlock.font)
                    .foregroundColor(theme.codeBlock.textColor)
                    .padding(theme.codeBlock.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
        .onChange(of: trimmedContent) { newContent in
            cachedHighlight = highlighter.highlightCode(newContent, language: language)
            cachedContent = newContent
        }
    }

    @ViewBuilder
    private var codeContent: some View {
        if isStreaming && revealConfig.isEnabled && revealConfig.mode == .continuous {
            continuousCodeContent
        } else {
            SwiftUI.Text(highlighted)
        }
    }

    @ViewBuilder
    private var continuousCodeContent: some View {
        let h = highlighted
        let totalCount = h.characters.count
        let splitAt = max(min(Int(revealDriver.smoothPosition), totalCount), 0)
        let frac = revealDriver.smoothPosition - Double(splitAt)
        let caughtUp = splitAt >= totalCount
        let parts = h.split(at: splitAt)

        animator.animate(
            revealed: parts.before,
            fresh: caughtUp ? AttributedString() : parts.after.prefix(1),
            progress: caughtUp ? 1.0 : frac,
            foregroundColor: theme.codeBlock.textColor
        )
        .onChange(of: trimmedContent) { _ in
            revealDriver.timeConstant = revealConfig.duration
            revealDriver.setTarget(Double(highlighted.characters.count))
        }
        .onAppear {
            revealDriver.snapTo(Double(highlighted.characters.count))
        }
        .onDisappear {
            revealDriver.stop()
        }
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

/// Header bar shared between `CodeBlockView` and `StreamingCodeBlockView`.
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
