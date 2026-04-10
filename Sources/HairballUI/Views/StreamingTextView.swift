import SwiftUI
import Hairball

// MARK: - Reveal Mode

/// How the reveal animation is driven.
public enum TokenRevealMode: Equatable, Sendable {
    /// Tokens are buffered into discrete batches. Each batch animates fully
    /// before the next one starts. `duration` controls both animation length
    /// and buffer window.
    case batched

    /// A smooth cursor continuously chases the stream at 60fps.
    /// `duration` controls the smoothing time constant — lower values
    /// track the stream tightly, higher values create a trailing effect.
    case continuous
}

// MARK: - Token Reveal Configuration

/// Controls the timing and mode of token reveal animations during streaming.
/// Use `.tokenAnimator()` to control the visual appearance.
public struct TokenRevealConfig: Equatable, Sendable {
    /// Controls animation timing.
    /// - **Batched mode**: batch duration and buffer window.
    /// - **Continuous mode**: smoothing time constant (lower = tighter tracking).
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

/// Drives a smooth floating-point position toward a target at 60fps
/// using exponential smoothing. Used by continuous reveal mode.
@MainActor
final class SmoothRevealDriver: ObservableObject {
    @Published var smoothPosition: Double = 0
    var timeConstant: Double = 0.15

    private var target: Double = 0
    private var timer: Timer?

    func setTarget(_ newTarget: Double) {
        target = newTarget
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func snapTo(_ value: Double) {
        smoothPosition = value
        target = value
    }

    /// Snap to target and stop — call when streaming ends.
    func finish() {
        smoothPosition = target
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let dt = 1.0 / 60.0
        let gap = target - smoothPosition

        if abs(gap) < 0.5 {
            smoothPosition = target
            timer?.invalidate()
            timer = nil
            return
        }

        // Exponential smoothing for the bulk, with a minimum speed
        // floor proportional to timeConstant so the final approach
        // doesn't visibly decelerate but the slider still works.
        let alpha = 1.0 - exp(-dt / max(timeConstant, 0.005))
        let expStep = gap * alpha
        let minCharsPerSec = 2.0 / max(timeConstant, 0.01)
        let minStep = max(minCharsPerSec * dt, 0.5)
        let step = gap > 0
            ? max(expStep, min(minStep, gap))
            : min(expStep, max(-minStep, gap))
        smoothPosition += step
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - AnimatableTokenView

/// Bridges SwiftUI's `Animatable` protocol to produce real intermediate
/// progress values during batched animation.
private struct AnimatableTokenView: View, Animatable {
    var progress: Double
    let revealed: AttributedString
    let fresh: AttributedString
    let foregroundColor: Color
    let animator: any TokenAnimator

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        animator.animate(
            revealed: revealed,
            fresh: fresh,
            progress: progress,
            foregroundColor: foregroundColor
        )
    }
}

// MARK: - StreamingTextView

/// Renders inline nodes with animation on newly arrived characters.
///
/// Supports two modes:
/// - **Batched**: discrete animation cycles with coalescing.
/// - **Continuous**: smooth 60fps pursuit of the stream position.
public struct StreamingTextView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.tokenRevealConfig) private var revealConfig
    @Environment(\.tokenAnimator) private var animator

    private let content: [InlineNode]
    private let isStreaming: Bool

    @State private var revealedLength: Int = 0
    @State private var animatingToLength: Int = 0
    @State private var animationProgress: Double = 1.0
    @StateObject private var revealDriver = SmoothRevealDriver()

    public init(content: [InlineNode], isStreaming: Bool = true) {
        self.content = content
        self.isStreaming = isStreaming
    }

    private var currentPlainLength: Int {
        content.plainText.count
    }

    public var body: some View {
        if !isStreaming || !revealConfig.isEnabled {
            InlineTextRenderer(theme: theme).render(content)
                .font(theme.bodyFont)
                .foregroundColor(theme.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } else if revealConfig.mode == .continuous {
            continuousBody
        } else {
            batchedBody
        }
    }

    // MARK: - Continuous Mode

    @ViewBuilder
    private var continuousBody: some View {
        let renderer = InlineTextRenderer(theme: theme)
        let splitAt = max(Int(revealDriver.smoothPosition), 0)
        let totalLength = currentPlainLength
        let (revealed, allFresh) = renderer.renderAndSplit(content, at: splitAt)

        let frac = revealDriver.smoothPosition - Double(splitAt)
        let edgeChar = allFresh.prefix(1)
        let caughtUp = splitAt >= totalLength

        animator.animate(
            revealed: revealed,
            fresh: caughtUp ? AttributedString() : edgeChar,
            progress: caughtUp ? 1.0 : frac,
            foregroundColor: theme.foregroundColor
        )
        .font(theme.bodyFont)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
        .onChange(of: currentPlainLength) { newLength in
            revealDriver.timeConstant = revealConfig.duration
            revealDriver.setTarget(Double(newLength))
        }
        .onChange(of: revealConfig.duration) { newDuration in
            revealDriver.timeConstant = newDuration
        }
        .onAppear {
            // Start from 0 so any content that accumulated before
            // the view appeared gets smoothly revealed, not skipped.
            revealDriver.timeConstant = revealConfig.duration
            revealDriver.snapTo(0)
            revealDriver.setTarget(Double(currentPlainLength))
        }
        .onDisappear {
            revealDriver.stop()
        }
    }

    // MARK: - Batched Mode

    @ViewBuilder
    private var batchedBody: some View {
        let renderer = InlineTextRenderer(theme: theme)
        let (revealed, allFresh) = renderer.renderAndSplit(content, at: revealedLength)
        let fresh = allFresh.prefix(max(animatingToLength - revealedLength, 0))

        AnimatableTokenView(
            progress: animationProgress,
            revealed: revealed,
            fresh: fresh,
            foregroundColor: theme.foregroundColor,
            animator: animator
        )
        .font(theme.bodyFont)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
        .onChange(of: currentPlainLength) { newLength in
            if animationProgress >= 1.0 && newLength > animatingToLength {
                animatingToLength = newLength
                startAnimationCycle()
            }
        }
        .onAppear {
            revealedLength = currentPlainLength
            animatingToLength = currentPlainLength
        }
    }

    private func startAnimationCycle() {
        animationProgress = 0

        withAnimation(.easeOut(duration: revealConfig.duration)) {
            animationProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + revealConfig.duration) {
            revealedLength = animatingToLength

            if currentPlainLength > animatingToLength {
                animatingToLength = currentPlainLength
                startAnimationCycle()
            }
        }
    }
}
