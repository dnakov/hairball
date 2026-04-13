import SwiftUI

/// Renders an `AttributedString` with streaming reveal via TextRenderer.
/// Single component for all block types — paragraphs, headings, code blocks, etc.
///
/// When the block is not yet complete, wraps in a `TimelineView(.animation)` to
/// provide continuous 60fps redraws so effects like Matrix rain can animate
/// independently of token arrivals.

struct RevealedText: View {
    @Environment(\.streamingTextEffect) private var effect
    @Environment(\.revealGranularity) private var granularity

    let attributedString: AttributedString
    let revealPosition: Double
    let blockComplete: Bool

    init(attributedString: AttributedString, revealPosition: Double, blockComplete: Bool = true) {
        self.attributedString = attributedString
        self.revealPosition = revealPosition
        self.blockComplete = blockComplete
    }

    private var needsTimeline: Bool {
        !blockComplete && granularity != .character
    }

    var body: some View {
        let splitAt = max(min(Int(revealPosition), attributedString.characters.count), 0)
        let renderer = effect ?? RevealEffect()

        // Always use TimelineView to avoid a view-identity swap that
        // flashes raw content when blockComplete toggles mid-stream.
        TimelineView(.animation) { timeline in
            let time = needsTimeline ? timeline.date.timeIntervalSinceReferenceDate : 0
            SwiftUI.Text(attributedString)
                .textRenderer(StreamingEffectRenderer(
                    effect: renderer,
                    revealedCount: splitAt,
                    granularity: granularity,
                    blockComplete: blockComplete,
                    time: time
                ))
        }
    }
}
