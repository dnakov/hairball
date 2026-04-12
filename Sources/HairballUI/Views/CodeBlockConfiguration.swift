import SwiftUI
import Hairball

/// Configuration object for code block rendering, matching `CodeBlockConfiguration`
/// from the original binary. Gives you full control over code block presentation.
public struct CodeBlockConfiguration {
    public let language: String?
    public let code: String
    public let highlightedCode: AttributedString
    public let theme: MarkdownTheme

    public init(
        language: String?,
        code: String,
        highlightedCode: AttributedString,
        theme: MarkdownTheme
    ) {
        self.language = language
        self.code = code
        self.highlightedCode = highlightedCode
        self.theme = theme
    }

    /// Whether this is a recognized programming language.
    public var hasLanguage: Bool {
        guard let language else { return false }
        return !language.isEmpty
    }

    /// Display name for the language label.
    public var languageDisplayName: String {
        language?.uppercased() ?? ""
    }

    /// The number of lines in the code content.
    public var lineCount: Int {
        code.components(separatedBy: "\n").count
    }
}

/// Protocol for customizing code block rendering.
/// Implement this and inject via environment to take full control of code block appearance.
public protocol CodeBlockRenderer {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: CodeBlockConfiguration) -> Body
}

/// Default implementation that renders the standard code block view.
public struct DefaultCodeBlockRenderer: CodeBlockRenderer {
    public init() {}

    public func makeBody(configuration: CodeBlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if configuration.hasLanguage {
                HStack {
                    SwiftUI.Text(configuration.languageDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                SwiftUI.Text(configuration.highlightedCode)
                    .font(configuration.theme.codeBlock.font)
                    .padding(configuration.theme.codeBlock.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(configuration.theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.theme.codeBlock.cornerRadius))
    }
}

// MARK: - Environment Key

private struct CodeBlockRendererKey: EnvironmentKey {
    static let defaultValue: AnyCodeBlockRenderer = AnyCodeBlockRenderer(DefaultCodeBlockRenderer())
}

extension EnvironmentValues {
    public var codeBlockRenderer: AnyCodeBlockRenderer {
        get { self[CodeBlockRendererKey.self] }
        set { self[CodeBlockRendererKey.self] = newValue }
    }
}

extension View {
    public func codeBlockRenderer(_ renderer: some CodeBlockRenderer) -> some View {
        environment(\.codeBlockRenderer, AnyCodeBlockRenderer(renderer))
    }
}

/// Type-erased code block renderer.
public struct AnyCodeBlockRenderer: CodeBlockRenderer, @unchecked Sendable {
    private let _makeBody: (CodeBlockConfiguration) -> AnyView

    public init(_ renderer: some CodeBlockRenderer) {
        _makeBody = { AnyView(renderer.makeBody(configuration: $0)) }
    }

    public func makeBody(configuration: CodeBlockConfiguration) -> some View {
        _makeBody(configuration)
    }
}
