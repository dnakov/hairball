import SwiftUI

// MARK: - MarkdownThemeConfiguration

public struct MarkdownThemeConfiguration: Sendable {
    public var theme: MarkdownTheme
    public var isCodeBlockSyntaxHighlightingEnabled: Bool
    public var parseLatex: Bool
    public var chunkMarkdownParagraphs: Bool
    public var softBreakMode: SoftBreakMode

    public init(
        theme: MarkdownTheme = .default,
        isCodeBlockSyntaxHighlightingEnabled: Bool = false,
        parseLatex: Bool = false,
        chunkMarkdownParagraphs: Bool = false,
        softBreakMode: SoftBreakMode = .space
    ) {
        self.theme = theme
        self.isCodeBlockSyntaxHighlightingEnabled = isCodeBlockSyntaxHighlightingEnabled
        self.parseLatex = parseLatex
        self.chunkMarkdownParagraphs = chunkMarkdownParagraphs
        self.softBreakMode = softBreakMode
    }

    /// Configuration for an assistant chat bubble.
    public static let assistantBubble = MarkdownThemeConfiguration(
        theme: .assistantBubble,
        isCodeBlockSyntaxHighlightingEnabled: true,
        parseLatex: true,
        chunkMarkdownParagraphs: true
    )

    /// Configuration for a user chat bubble.
    public static let userBubble = MarkdownThemeConfiguration(
        theme: .userBubble,
        isCodeBlockSyntaxHighlightingEnabled: false,
        parseLatex: true,
        chunkMarkdownParagraphs: false
    )

    /// Configuration for a user chat bubble in pending state.
    public static let userBubblePending = MarkdownThemeConfiguration(
        theme: .userBubblePending,
        isCodeBlockSyntaxHighlightingEnabled: false,
        parseLatex: true,
        chunkMarkdownParagraphs: false
    )
}

// MARK: - ChatMessageConfiguration

public struct ChatMessageConfiguration: Sendable {
    public var role: Role
    public var themeConfiguration: MarkdownThemeConfiguration

    public enum Role: Sendable {
        case assistant
        case user
        case userPending
    }

    public init(role: Role, themeConfiguration: MarkdownThemeConfiguration? = nil) {
        self.role = role
        self.themeConfiguration = themeConfiguration ?? {
            switch role {
            case .assistant: return .assistantBubble
            case .user: return .userBubble
            case .userPending: return .userBubblePending
            }
        }()
    }
}

// MARK: - Environment Keys

private struct MarkdownThemeConfigurationKey: EnvironmentKey {
    static let defaultValue: MarkdownThemeConfiguration = MarkdownThemeConfiguration()
}

private struct ChatMessageConfigurationKey: EnvironmentKey {
    static let defaultValue: ChatMessageConfiguration? = nil
}

extension EnvironmentValues {
    public var markdownThemeConfiguration: MarkdownThemeConfiguration {
        get { self[MarkdownThemeConfigurationKey.self] }
        set { self[MarkdownThemeConfigurationKey.self] = newValue }
    }

    public var chatMessageConfiguration: ChatMessageConfiguration? {
        get { self[ChatMessageConfigurationKey.self] }
        set { self[ChatMessageConfigurationKey.self] = newValue }
    }
}

extension View {
    public func markdownConfiguration(_ configuration: MarkdownThemeConfiguration) -> some View {
        environment(\.markdownThemeConfiguration, configuration)
            .environment(\.markdownTheme, configuration.theme)
            .environment(\.softBreakMode, configuration.softBreakMode)
    }

    public func chatMessageConfiguration(_ configuration: ChatMessageConfiguration) -> some View {
        environment(\.chatMessageConfiguration, configuration)
            .markdownConfiguration(configuration.themeConfiguration)
    }
}
