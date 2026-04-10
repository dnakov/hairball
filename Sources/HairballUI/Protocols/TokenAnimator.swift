import SwiftUI

// MARK: - TokenAnimator Protocol

/// Controls how newly arrived tokens appear during streaming.
///
/// The library handles parsing, block rendering, timing, and state tracking.
/// Your animator controls only the visual treatment of revealed vs. fresh text.
///
/// ```swift
/// struct MyAnimator: TokenAnimator {
///     func animate(
///         revealed: AttributedString,
///         fresh: AttributedString,
///         progress: Double,
///         foregroundColor: Color
///     ) -> Text {
///         var f = fresh
///         f.foregroundColor = foregroundColor.opacity(progress)
///         return Text(revealed) + Text(f)
///     }
/// }
///
/// // Apply via environment:
/// MarkdownBlocksView(blocks: blocks, isStreaming: true)
///     .tokenAnimator(MyAnimator())
/// ```
public protocol TokenAnimator {
    /// Compose revealed and fresh text into a single `Text` view.
    ///
    /// - Parameters:
    ///   - revealed: Characters that have already appeared (should be fully visible).
    ///   - fresh: Characters that just arrived (animate based on `progress`).
    ///   - progress: Animation progress from 0 (just arrived) to 1 (fully visible).
    ///   - foregroundColor: The theme's base text color.
    /// - Returns: A composed `Text` view.
    func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text
}

// MARK: - Built-in Animators

/// Fades new tokens from transparent to opaque. This is the default animator.
public struct FadeTokenAnimator: TokenAnimator {
    public init() {}

    public func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text {
        if fresh.characters.isEmpty { return Text(revealed) }
        var f = fresh
        f.foregroundColor = foregroundColor.opacity(progress)
        if revealed.characters.isEmpty { return Text(f) }
        return Text(revealed) + Text(f)
    }
}

/// Reveals characters left-to-right as progress advances.
public struct RevealTokenAnimator: TokenAnimator {
    public init() {}

    public func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text {
        if fresh.characters.isEmpty { return Text(revealed) }
        let visibleCount = Int(Double(fresh.characters.count) * progress)
        guard visibleCount > 0 else {
            return revealed.characters.isEmpty ? Text("") : Text(revealed)
        }
        let visibleFresh = fresh.prefix(visibleCount)
        return revealed.characters.isEmpty ? Text(visibleFresh) : Text(revealed) + Text(visibleFresh)
    }
}

/// Shows tokens instantly with no animation.
public struct InstantTokenAnimator: TokenAnimator {
    public init() {}

    public func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text {
        if revealed.characters.isEmpty { return Text(fresh) }
        if fresh.characters.isEmpty { return Text(revealed) }
        return Text(revealed) + Text(fresh)
    }
}

// MARK: - Environment Key

private struct TokenAnimatorKey: EnvironmentKey {
    static let defaultValue: any TokenAnimator = FadeTokenAnimator()
}

extension EnvironmentValues {
    public var tokenAnimator: any TokenAnimator {
        get { self[TokenAnimatorKey.self] }
        set { self[TokenAnimatorKey.self] = newValue }
    }
}

extension View {
    /// Sets the token animator used for streaming text appearance.
    public func tokenAnimator(_ animator: any TokenAnimator) -> some View {
        environment(\.tokenAnimator, animator)
    }
}
