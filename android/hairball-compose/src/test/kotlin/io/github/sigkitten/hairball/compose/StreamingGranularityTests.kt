package io.github.sigkitten.hairball.compose

import kotlin.test.Test
import kotlin.test.assertEquals

class StreamingGranularityTests {
    @Test
    fun blockGranularityKeepsCharactersUnsettledUntilBlockCompletes() {
        val frame = computeEffectFrame(
            text = "Hello",
            glyphCount = 5,
            revealedCount = 3,
            granularity = RevealGranularity.Block,
            blockComplete = false,
            time = 0.0,
        )

        assertEquals(3, frame.revealedCount)
        assertEquals(0, frame.settledCount)
    }

    @Test
    fun lineGranularitySettlesUpToLastCompletedLineBreak() {
        val frame = computeEffectFrame(
            text = "Line 1\nLine 2",
            glyphCount = 13,
            revealedCount = 9,
            granularity = RevealGranularity.Line,
            blockComplete = false,
            time = 0.0,
        )

        assertEquals(9, frame.revealedCount)
        assertEquals(7, frame.settledCount)
    }

    @Test
    fun matrixEffectDefaultsToBlockGranularity() {
        assertEquals(RevealGranularity.Block, MatrixDecodeEffect().recommendedGranularity)
        assertEquals(RevealGranularity.Block, PhosphorCrtEffect().recommendedGranularity)
        assertEquals(RevealGranularity.Character, GlowCursorEffect().recommendedGranularity)
    }
}
