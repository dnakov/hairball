import SwiftUI
import Highlightr

// MARK: - CodeSyntaxHighlighter Protocol

public protocol CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> AttributedString
}

// MARK: - DefaultCodeSyntaxHighlighter

public struct DefaultCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    public init() {}

    public func highlightCode(_ code: String, language: String?) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.font = .system(.body, design: .monospaced)
        return attributed
    }
}

// MARK: - HighlightrCodeSyntaxHighlighter

public final class HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private var currentTheme: String
    private let lock = NSLock()
    private var _highlightr: Highlightr?
    private var isInitialized = false

    private var highlightr: Highlightr? {
        if !isInitialized {
            _highlightr = Highlightr()
            _highlightr?.setTheme(to: currentTheme)
            isInitialized = true
        }
        return _highlightr
    }

    public init(theme: String = "atom-one-dark") {
        self.currentTheme = theme
    }

    /// The name of the current Highlightr theme.
    public var themeName: String {
        lock.withLock { currentTheme }
    }

    /// Change the syntax highlighting theme at runtime.
    /// Theme names correspond to highlight.js CSS themes bundled with Highlightr
    /// (e.g. "atom-one-dark", "github", "monokai", "xcode", "vs2015").
    @discardableResult
    public func setTheme(_ name: String) -> Bool {
        lock.withLock {
            currentTheme = name
            let success = highlightr?.setTheme(to: name) ?? false
            return success
        }
    }

    /// List all available Highlightr theme names.
    public var availableThemes: [String] {
        lock.withLock {
            highlightr?.availableThemes() ?? []
        }
    }

    public func highlightCode(_ code: String, language: String?) -> AttributedString {
        let resolvedLanguage = language.map { Self.normalizeLanguage($0) }

        let result: NSAttributedString? = lock.withLock {
            highlightr?.highlight(code, as: resolvedLanguage)
        }

        if let result {
            return AttributedString(result)
        }

        var attributed = AttributedString(code)
        attributed.font = .system(.body, design: .monospaced)
        return attributed
    }

    // MARK: - Language Normalization

    private static func normalizeLanguage(_ language: String) -> String {
        switch language.lowercased() {
        case "js", "javascript":
            return "javascript"
        case "py", "python":
            return "python"
        case "rb", "ruby":
            return "ruby"
        case "ts", "typescript":
            return "typescript"
        case "sh", "bash", "shell", "zsh":
            return "bash"
        case "yml":
            return "yaml"
        case "objc", "objective-c":
            return "objectivec"
        default:
            return language.lowercased()
        }
    }
}

// MARK: - Theme Presets

extension HighlightrCodeSyntaxHighlighter {
    public static let atomOneDark = HighlightrCodeSyntaxHighlighter(theme: "atom-one-dark")
    public static let atomOneLight = HighlightrCodeSyntaxHighlighter(theme: "atom-one-light")
    public static let github = HighlightrCodeSyntaxHighlighter(theme: "github")
    public static let githubDark = HighlightrCodeSyntaxHighlighter(theme: "github-dark")
    public static let monokai = HighlightrCodeSyntaxHighlighter(theme: "monokai")
    public static let xcode = HighlightrCodeSyntaxHighlighter(theme: "xcode")
    public static let vs2015 = HighlightrCodeSyntaxHighlighter(theme: "vs2015")
}

// MARK: - Environment Key

private struct CodeSyntaxHighlighterKey: EnvironmentKey {
    static let defaultValue: any CodeSyntaxHighlighter = HighlightrCodeSyntaxHighlighter()
}

extension EnvironmentValues {
    public var codeSyntaxHighlighter: any CodeSyntaxHighlighter {
        get { self[CodeSyntaxHighlighterKey.self] }
        set { self[CodeSyntaxHighlighterKey.self] = newValue }
    }
}

extension View {
    public func codeSyntaxHighlighter(_ highlighter: some CodeSyntaxHighlighter) -> some View {
        environment(\.codeSyntaxHighlighter, highlighter)
    }
}
