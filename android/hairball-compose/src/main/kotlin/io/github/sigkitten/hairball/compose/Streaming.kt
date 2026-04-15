package io.github.sigkitten.hairball.compose

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.sigkitten.hairball.core.BlockNode
import io.github.sigkitten.hairball.core.CheckboxState
import io.github.sigkitten.hairball.core.Document
import io.github.sigkitten.hairball.core.IdentifiedBlock
import io.github.sigkitten.hairball.core.InlineNode
import io.github.sigkitten.hairball.core.MarkdownParser
import io.github.sigkitten.hairball.core.MarkdownProcessor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

enum class TokenRevealMode {
    Continuous,
    Linear,
}

data class TokenRevealConfig(
    val duration: Double = 0.15,
    val isEnabled: Boolean = true,
    val mode: TokenRevealMode = TokenRevealMode.Continuous,
) {
    companion object {
        val Default = TokenRevealConfig()
        val Disabled = TokenRevealConfig(isEnabled = false)
    }
}

sealed interface RevealGranularity {
    data object Character : RevealGranularity
    data object Block : RevealGranularity
    data object Line : RevealGranularity
    data class Chunk(val size: Int) : RevealGranularity
}

interface StreamingTextEffect {
    val recommendedGranularity: RevealGranularity
        get() = RevealGranularity.Character
}

interface ScriptableEffectContext {
    val revealedCount: Int
    val settledCount: Int
    val time: Double
    val glyphCount: Int
    val blockComplete: Boolean

    fun effectiveTrail(ownTrail: Int): Int = max(ownTrail, revealedCount - settledCount)
}

data class StreamingEffectFrame(
    override val revealedCount: Int,
    override val settledCount: Int,
    override val time: Double,
    override val glyphCount: Int,
    override val blockComplete: Boolean,
    val granularity: RevealGranularity,
) : ScriptableEffectContext

class FadeEdgeEffect(val edgeWidth: Int = 4) : StreamingTextEffect
class GlowCursorEffect(val glowRadius: Float = 12f) : StreamingTextEffect
class WaveRevealEffect(val amplitude: Float = 6f, val wavelength: Int = 12) : StreamingTextEffect
class FireTrailEffect(val trailLength: Int = 18) : StreamingTextEffect
class SparkleEffect(val sparkleCount: Int = 8) : StreamingTextEffect
class RainbowEffect(val trailLength: Int = 16) : StreamingTextEffect
class CombinedEffect(
    val effects: List<StreamingTextEffect> = listOf(
        WaveRevealEffect(amplitude = 4f, wavelength = 10),
        GlowCursorEffect(glowRadius = 10f),
        SparkleEffect(sparkleCount = 10),
    ),
) : StreamingTextEffect {
    override val recommendedGranularity: RevealGranularity
        get() = effects.firstOrNull()?.recommendedGranularity ?: RevealGranularity.Character
}
class ExplosionEffect(val burstRadius: Float = 14f, val particleCount: Int = 10, val trailWidth: Int = 6) : StreamingTextEffect
class NyanCatEffect : StreamingTextEffect
class MatrixDecodeEffect(val trailLength: Int = 8) : StreamingTextEffect {
    override val recommendedGranularity: RevealGranularity = RevealGranularity.Block
}
class PhosphorCrtEffect(val decayLength: Int = 20) : StreamingTextEffect {
    override val recommendedGranularity: RevealGranularity = RevealGranularity.Block
}
class ShockwaveEffect(val waveRadius: Float = 40f, val displacement: Float = 3f, val trailWidth: Int = 8) : StreamingTextEffect

fun computeEffectFrame(
    text: String = "",
    glyphCount: Int,
    revealedCount: Int,
    granularity: RevealGranularity,
    blockComplete: Boolean,
    time: Double,
): StreamingEffectFrame {
    val clampedRevealed = revealedCount.coerceIn(0, glyphCount)
    val settledCount = when (granularity) {
        RevealGranularity.Character -> clampedRevealed
        RevealGranularity.Block -> if (blockComplete || clampedRevealed >= glyphCount) clampedRevealed else 0
        RevealGranularity.Line -> {
            if (blockComplete || clampedRevealed >= glyphCount) {
                clampedRevealed
            } else {
                text.take(clampedRevealed).lastIndexOf('\n').let { if (it == -1) 0 else it + 1 }
            }
        }
        is RevealGranularity.Chunk -> {
            if (blockComplete || clampedRevealed >= glyphCount) {
                clampedRevealed
            } else {
                val chunkSize = granularity.size.coerceAtLeast(1)
                (clampedRevealed / chunkSize) * chunkSize
            }
        }
    }

    return StreamingEffectFrame(
        revealedCount = clampedRevealed,
        settledCount = settledCount,
        time = time,
        glyphCount = glyphCount,
        blockComplete = blockComplete,
        granularity = granularity,
    )
}

class SmoothRevealDriver {
    var smoothPosition by mutableDoubleStateOf(0.0)
        private set

    var hasCaughtUp by mutableStateOf(true)
        private set

    var timeConstant by mutableDoubleStateOf(0.15)
    var linearMode by mutableStateOf(false)

    private var targetPosition by mutableDoubleStateOf(0.0)

    fun setTarget(newTarget: Double) {
        targetPosition = newTarget
        hasCaughtUp = false
    }

    fun snapTo(value: Double) {
        smoothPosition = value
        targetPosition = value
        hasCaughtUp = true
    }

    fun tick() {
        val dt = 1.0 / 60.0
        val gap = targetPosition - smoothPosition

        if (kotlin.math.abs(gap) < 0.5) {
            smoothPosition = targetPosition
            hasCaughtUp = true
            return
        }

        if (linearMode) {
            val charsPerSecond = 100.0 / max(timeConstant, 0.01)
            smoothPosition = min(smoothPosition + (charsPerSecond * dt), targetPosition)
            hasCaughtUp = false
            return
        }

        val alpha = 1.0 - exp(-dt / max(timeConstant, 0.005))
        val expStep = gap * alpha
        val minCharsPerSecond = 2.0 / max(timeConstant, 0.01)
        val minStep = max(minCharsPerSecond * dt, 0.5)
        val step = if (gap > 0) {
            max(expStep, min(minStep, gap))
        } else {
            min(expStep, max(-minStep, gap))
        }
        smoothPosition += step
        hasCaughtUp = false
    }
}

fun blockPlainTextLength(block: BlockNode): Int =
    when (block) {
        is BlockNode.DocumentBlock -> block.children.sumOf(::blockPlainTextLength)
        is BlockNode.Heading -> block.content.plainText.length
        is BlockNode.Paragraph -> block.content.plainText.length
        is BlockNode.CodeBlock -> block.content.trimEnd('\n').length
        is BlockNode.BlockQuote -> block.children.sumOf(::blockPlainTextLength)
        is BlockNode.OrderedList -> block.items.sumOf { item -> item.children.sumOf(::blockPlainTextLength) }
        is BlockNode.UnorderedList -> block.items.sumOf { item -> item.children.sumOf(::blockPlainTextLength) }
        is BlockNode.Table -> {
            val head = block.head.cells.sumOf { cell -> cell.content.plainText.length }
            val body = block.body.sumOf { row -> row.cells.sumOf { cell -> cell.content.plainText.length } }
            head + body
        }
        is BlockNode.ThematicBreak -> 0
        is BlockNode.HtmlBlock -> block.content.length
        is BlockNode.CustomBlock -> block.content.length
        is BlockNode.LatexBlock -> block.content.length
        is BlockNode.BlockDirective -> block.children.sumOf(::blockPlainTextLength)
    }

private val List<InlineNode>.plainText: String
    get() = joinToString(separator = "") { inline ->
        when (inline) {
            is InlineNode.Text -> inline.value
            is InlineNode.Emphasis -> inline.children.plainText
            is InlineNode.Strong -> inline.children.plainText
            is InlineNode.Strikethrough -> inline.children.plainText
            is InlineNode.InlineCode -> inline.value
            is InlineNode.Link -> inline.children.plainText
            is InlineNode.Image -> inline.children.plainText
            is InlineNode.SoftBreak -> " "
            is InlineNode.HardBreak, is InlineNode.LineBreak -> "\n"
            is InlineNode.InlineHtml -> inline.value
            is InlineNode.Latex -> inline.content
            is InlineNode.Citation -> inline.title ?: "[${inline.index}]"
            is InlineNode.CustomInline -> inline.content
        }
    }

class StreamingMarkdownRenderer(
    private val processors: List<MarkdownProcessor> = emptyList(),
    private val parser: MarkdownParser = MarkdownParser(),
    val throttleIntervalMillis: Long = 16L,
) {
    private val _document = MutableStateFlow(Document(emptyList()))
    val document: StateFlow<Document> = _document.asStateFlow()

    private val _identifiedBlocks = MutableStateFlow(emptyList<IdentifiedBlock>())
    val identifiedBlocks: StateFlow<List<IdentifiedBlock>> = _identifiedBlocks.asStateFlow()

    private val _rawText = MutableStateFlow("")
    val rawText: StateFlow<String> = _rawText.asStateFlow()

    private val _isFinished = MutableStateFlow(false)
    val isFinished: StateFlow<Boolean> = _isFinished.asStateFlow()

    private val _isEmpty = MutableStateFlow(true)
    val isEmpty: StateFlow<Boolean> = _isEmpty.asStateFlow()

    fun append(text: String) {
        _rawText.value += text
        _isEmpty.value = _rawText.value.isEmpty()
        performUpdate()
    }

    fun finish() {
        _isFinished.value = true
        performUpdate()
    }

    fun reset() {
        _rawText.value = ""
        _document.value = Document(emptyList())
        _identifiedBlocks.value = emptyList()
        _isFinished.value = false
        _isEmpty.value = true
    }

    fun setContent(markdown: String) {
        reset()
        _rawText.value = markdown
        _isEmpty.value = markdown.isEmpty()
        performUpdate()
    }

    private fun performUpdate() {
        var doc = parser.parse(_rawText.value)
        processors.forEach { doc = it.process(doc) }
        val blocks = if (_isFinished.value) doc.blocks else stabilizeLastBlock(doc.blocks)
        _document.value = doc.copy(blocks = blocks)
        _identifiedBlocks.value = IdentifiedBlock.identify(blocks)
    }

    private fun stabilizeLastBlock(blocks: List<BlockNode>): List<BlockNode> {
        val last = blocks.lastOrNull() ?: return blocks
        if (last is BlockNode.Paragraph) {
            val text = last.content.joinToString(separator = "") {
                when (it) {
                    is InlineNode.Text -> it.value
                    else -> ""
                }
            }.trim()
            if (text.startsWith("|") && text.count { it == '|' } >= 3) {
                return blocks.dropLast(1)
            }
        }
        return blocks
    }
}
