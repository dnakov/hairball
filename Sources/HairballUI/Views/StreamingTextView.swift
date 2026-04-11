import SwiftUI
import Hairball

// MARK: - Reveal Mode

/// How the reveal animation is driven.
public enum TokenRevealMode: Equatable, Sendable {
    /// A smooth cursor continuously chases the stream at 60fps.
    /// `duration` controls the smoothing time constant — lower values
    /// track the stream tightly, higher values create a trailing effect.
    case continuous

    /// Constant-speed reveal at 60fps. The cursor advances at a fixed rate
    /// regardless of how much content is waiting. `duration` controls speed:
    /// lower = faster, higher = slower.
    case linear
}

// MARK: - Token Reveal Configuration

/// Controls the timing and mode of token reveal animations during streaming.
/// Use `.tokenAnimator()` to control the visual appearance.
public struct TokenRevealConfig: Equatable, Sendable {
    /// Controls animation timing.
    /// - **Continuous**: smoothing time constant (lower = tighter tracking).
    /// - **Linear**: speed control — `duration` of 0.1 ≈ 1000 chars/sec, 1.0 ≈ 100 chars/sec.
    public var duration: Double
    /// Whether token reveal animation is enabled.
    public var isEnabled: Bool
    /// How the reveal is driven.
    public var mode: TokenRevealMode

    public init(
        duration: Double = 0.15,
        isEnabled: Bool = true,
        mode: TokenRevealMode = .continuous
    ) {
        self.duration = duration
        self.isEnabled = isEnabled
        self.mode = mode
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

// MARK: - Smooth Reveal Driver

/// Drives a single smooth cursor position toward a target at 60fps.
/// One driver per `MarkdownBlocksView` — shared across all blocks.
@MainActor
public final class SmoothRevealDriver: ObservableObject {
    @Published public var smoothPosition: Double = 0
    @Published public var hasCaughtUp: Bool = true
    public var timeConstant: Double = 0.15
    public var linearMode: Bool = false

    private var target: Double = 0
    private var timer: Timer?

    public init() {}

    public func setTarget(_ newTarget: Double) {
        target = newTarget
        hasCaughtUp = false
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    public func snapTo(_ value: Double) {
        smoothPosition = value
        target = value
    }

    public func finish() {
        smoothPosition = target
        hasCaughtUp = true
        timer?.invalidate()
        timer = nil
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let dt = 1.0 / 60.0
        let gap = target - smoothPosition

        if abs(gap) < 0.5 {
            smoothPosition = target
            hasCaughtUp = true
            timer?.invalidate()
            timer = nil
            return
        }

        if linearMode {
            let charsPerSec = 100.0 / max(timeConstant, 0.01)
            smoothPosition = min(smoothPosition + charsPerSec * dt, target)
        } else {
            let alpha = 1.0 - exp(-dt / max(timeConstant, 0.005))
            let expStep = gap * alpha
            let minCharsPerSec = 2.0 / max(timeConstant, 0.01)
            let minStep = max(minCharsPerSec * dt, 0.5)
            let step = gap > 0
                ? max(expStep, min(minStep, gap))
                : min(expStep, max(-minStep, gap))
            smoothPosition += step
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - StreamingTextView (Stateless)

/// Renders inline nodes with a reveal cursor at `revealPosition`.
/// Pure view — no timers, no state. The cursor is driven externally
/// by `MarkdownBlocksView`'s single `SmoothRevealDriver`.
public struct StreamingTextView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.tokenAnimator) private var animator

    private let content: [InlineNode]
    private let revealPosition: Double

    public init(content: [InlineNode], revealPosition: Double) {
        self.content = content
        self.revealPosition = revealPosition
    }

    public var body: some View {
        let renderer = InlineTextRenderer(theme: theme)
        let totalLength = content.plainText.count
        let splitAt = max(min(Int(revealPosition), totalLength), 0)
        let frac = revealPosition - Double(splitAt)
        let caughtUp = splitAt >= totalLength
        let (revealed, allFresh) = renderer.renderAndSplit(content, at: splitAt)

        animator.animate(
            revealed: revealed,
            fresh: caughtUp ? AttributedString() : allFresh.prefix(1),
            progress: caughtUp ? 1.0 : frac,
            foregroundColor: theme.foregroundColor
        )
        .font(theme.bodyFont)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
    }
}

// MARK: - Block Plain Text Length

/// Computes plain text character count for a block, used for cursor offset calculation.
public func blockPlainTextLength(_ block: BlockNode) -> Int {
    switch block {
    case .paragraph(let content), .heading(_, let content):
        return content.plainText.count
    case .codeBlock(_, let code):
        let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
        return trimmed.count
    case .blockQuote(let children):
        return children.map(blockPlainTextLength).reduce(0, +)
    case .orderedList(_, _, let items):
        return items.flatMap(\.children).map(blockPlainTextLength).reduce(0, +)
    case .unorderedList(_, let items):
        return items.flatMap(\.children).map(blockPlainTextLength).reduce(0, +)
    case .table(_, let head, let body):
        let h = head.cells.flatMap(\.content).plainText.count
        let b = body.flatMap(\.cells).map { $0.content.plainText.count }.reduce(0, +)
        return h + b
    case .htmlBlock(let content), .customBlock(_, let content), .latexBlock(let content):
        return content.count
    case .thematicBreak:
        return 0
    case .document(let children), .blockDirective(_, _, let children):
        return children.map(blockPlainTextLength).reduce(0, +)
    }
}

