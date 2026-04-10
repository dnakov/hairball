import SwiftUI
import Hairball

// MARK: - Token Reveal Configuration

/// Controls how newly arrived tokens appear during streaming.
public struct TokenRevealConfig: Equatable, Sendable {
    /// Duration of the fade-in animation for new tokens.
    public var duration: Double
    /// Whether token reveal animation is enabled.
    public var isEnabled: Bool

    public init(duration: Double = 0.15, isEnabled: Bool = true) {
        self.duration = duration
        self.isEnabled = isEnabled
    }

    public static let `default` = TokenRevealConfig()
    public static let disabled = TokenRevealConfig(isEnabled: false)
    public static let fast = TokenRevealConfig(duration: 0.08)
    public static let slow = TokenRevealConfig(duration: 0.3)
}

// MARK: - Environment Key

private struct TokenRevealConfigKey: EnvironmentKey {
    static let defaultValue: TokenRevealConfig = .default
}

extension EnvironmentValues {
    public var tokenRevealConfig: TokenRevealConfig {
        get { self[TokenRevealConfigKey.self] }
        set { self[TokenRevealConfigKey.self] = newValue }
    }
}

extension View {
    public func tokenReveal(_ config: TokenRevealConfig) -> some View {
        environment(\.tokenRevealConfig, config)
    }
}

// MARK: - StreamingTextView

/// Renders inline nodes with a fade-in animation on newly arrived characters.
///
/// Tracks the previous plain-text length. When new content arrives (length grows),
/// the new characters render at opacity 0 and animate to opacity 1.
/// Already-revealed characters stay at full opacity.
///
/// Use this instead of `ParagraphView` for the actively streaming block.
public struct StreamingTextView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.tokenRevealConfig) private var revealConfig

    private let content: [InlineNode]
    private let isStreaming: Bool

    @State private var revealedLength: Int = 0
    @State private var revealOpacity: Double = 1.0

    public init(content: [InlineNode], isStreaming: Bool = true) {
        self.content = content
        self.isStreaming = isStreaming
    }

    private var currentPlainLength: Int {
        content.plainText.count
    }

    public var body: some View {
        if !isStreaming || !revealConfig.isEnabled {
            // Not streaming or reveal disabled — just render normally
            InlineTextRenderer(theme: theme).render(content)
                .font(theme.bodyFont)
                .foregroundColor(theme.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } else {
            // Streaming with reveal — split into revealed + fresh
            let plainText = content.plainText
            let revealed = min(revealedLength, plainText.count)

            InlineTextRenderer(theme: theme)
                .renderWithReveal(
                    content,
                    revealedCharacterCount: revealed,
                    freshOpacity: revealOpacity,
                    foregroundColor: theme.foregroundColor
                )
                .font(theme.bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .onChange(of: currentPlainLength) { newLength in
                    if newLength > revealedLength {
                        // New tokens arrived — start them invisible, fade in
                        revealOpacity = 0
                        withAnimation(.easeOut(duration: revealConfig.duration)) {
                            revealOpacity = 1
                        }
                        // After animation, mark these as revealed
                        DispatchQueue.main.asyncAfter(deadline: .now() + revealConfig.duration) {
                            revealedLength = newLength
                        }
                    }
                }
                .onAppear {
                    revealedLength = currentPlainLength
                }
        }
    }
}
