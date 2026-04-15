package io.github.sigkitten.hairball.compose

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.ParagraphStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import io.github.sigkitten.hairball.core.BlockNode
import io.github.sigkitten.hairball.core.CheckboxState
import io.github.sigkitten.hairball.core.Document
import io.github.sigkitten.hairball.core.IdentifiedBlock
import io.github.sigkitten.hairball.core.InlineNode
import io.github.sigkitten.hairball.core.MarkdownParser
import io.github.sigkitten.hairball.core.MarkdownProcessor
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlinx.coroutines.delay

interface CodeSyntaxHighlighter {
    fun highlightCode(code: String, language: String?): AnnotatedString
}

object DefaultCodeSyntaxHighlighter : CodeSyntaxHighlighter {
    override fun highlightCode(code: String, language: String?): AnnotatedString = AnnotatedString(code)
}

interface ImageProvider

@Composable
fun MarkdownView(
    markdown: String,
    modifier: Modifier = Modifier,
    theme: MarkdownTheme = MarkdownTheme.Default,
    parser: MarkdownParser = MarkdownParser(),
    processors: List<MarkdownProcessor> = emptyList(),
) {
    var document = parser.parse(markdown)
    processors.forEach { document = it.process(document) }
    MarkdownDocumentView(document = document, modifier = modifier, theme = theme)
}

@Composable
fun MarkdownDocumentView(
    document: Document,
    modifier: Modifier = Modifier,
    theme: MarkdownTheme = MarkdownTheme.Default,
) {
    MarkdownBlocksView(
        blocks = IdentifiedBlock.identify(document.blocks),
        modifier = modifier,
        theme = theme,
    )
}

@Composable
fun MarkdownBlocksView(
    blocks: List<IdentifiedBlock>,
    modifier: Modifier = Modifier,
    theme: MarkdownTheme = MarkdownTheme.Default,
    streamingEffect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    revealConfig: TokenRevealConfig = TokenRevealConfig.Disabled,
    streamingTimeSeconds: Float = 0f,
    streamFinished: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(theme.paragraphSpacingDp.dp),
    ) {
        val lastIndex = blocks.lastIndex
        blocks.forEachIndexed { index, item ->
            BlockNodeView(
                node = item.block,
                theme = theme,
                isActiveStreamingBlock = !streamFinished && index == lastIndex,
                streamingEffect = streamingEffect,
                revealGranularity = revealGranularity,
                revealConfig = revealConfig,
                streamingTimeSeconds = streamingTimeSeconds,
            )
        }
    }
}

@Composable
fun BlockNodeView(
    node: BlockNode,
    theme: MarkdownTheme = MarkdownTheme.Default,
    highlighter: CodeSyntaxHighlighter = DefaultCodeSyntaxHighlighter,
    isActiveStreamingBlock: Boolean = false,
    streamingEffect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    revealConfig: TokenRevealConfig = TokenRevealConfig.Disabled,
    streamingTimeSeconds: Float = 0f,
) {
    when (node) {
        is BlockNode.DocumentBlock -> MarkdownDocumentView(Document(node.children), theme = theme)
        is BlockNode.Heading -> {
            val style = theme.headingStyleSet[node.level]
            Text(
                text = renderInline(
                    node.content,
                    theme,
                    effect = streamingEffect,
                    revealGranularity = revealGranularity,
                    revealConfig = revealConfig,
                    isActiveStreamingBlock = isActiveStreamingBlock,
                    streamingTimeSeconds = streamingTimeSeconds,
                ),
                style = style.textStyle,
                color = if (style.color != Color.Unspecified) style.color else theme.foregroundColor,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        is BlockNode.Paragraph -> Text(
            renderInline(
                node.content,
                theme,
                effect = streamingEffect,
                revealGranularity = revealGranularity,
                revealConfig = revealConfig,
                isActiveStreamingBlock = isActiveStreamingBlock,
                streamingTimeSeconds = streamingTimeSeconds,
            ),
            style = theme.bodyTextStyle,
            color = theme.foregroundColor,
        )
        is BlockNode.CodeBlock -> Text(
            text = applyStreamingEffect(
                base = highlighter.highlightCode(node.content.trimEnd('\n'), node.language),
                effect = streamingEffect,
                revealGranularity = revealGranularity,
                revealConfig = revealConfig,
                isActiveStreamingBlock = isActiveStreamingBlock,
                streamingTimeSeconds = streamingTimeSeconds,
                baseColor = theme.codeBlock.textColor.takeUnless { it == Color.Unspecified } ?: theme.foregroundColor,
                preserveExistingColors = true,
            ),
            style = theme.codeBlock.textStyle,
            color = theme.codeBlock.textColor,
            modifier = Modifier
                .fillMaxWidth()
                .background(theme.codeBlock.backgroundColor)
                .padding(horizontal = theme.codeBlock.horizontalPaddingDp.dp, vertical = theme.codeBlock.verticalPaddingDp.dp)
                .horizontalScroll(rememberScrollState()),
        )
        is BlockNode.BlockQuote -> Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(theme.blockquote.backgroundColor)
                .padding(start = theme.blockquote.borderWidthDp.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(theme.paragraphSpacingDp.dp)) {
                node.children.forEach { child ->
                    BlockNodeView(
                        child,
                        theme,
                        highlighter,
                        isActiveStreamingBlock,
                        streamingEffect,
                        revealGranularity,
                        revealConfig,
                        streamingTimeSeconds,
                    )
                }
            }
        }
        is BlockNode.OrderedList -> Column(verticalArrangement = Arrangement.spacedBy(theme.list.itemSpacingDp.dp)) {
            node.items.forEachIndexed { index, item ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("${node.startIndex + index}.", style = theme.bodyTextStyle)
                    Column {
                        item.children.forEach { child ->
                            BlockNodeView(
                                child,
                                theme,
                                highlighter,
                                isActiveStreamingBlock,
                                streamingEffect,
                                revealGranularity,
                                revealConfig,
                                streamingTimeSeconds,
                            )
                        }
                    }
                }
            }
        }
        is BlockNode.UnorderedList -> Column(verticalArrangement = Arrangement.spacedBy(theme.list.itemSpacingDp.dp)) {
            node.items.forEach { item ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        when (item.checkbox) {
                            CheckboxState.Checked -> theme.list.checkboxCheckedSymbol
                            CheckboxState.Unchecked -> theme.list.checkboxUncheckedSymbol
                            null -> theme.list.bulletMarker.marker
                        },
                        style = theme.bodyTextStyle,
                    )
                    Column {
                        item.children.forEach { child ->
                            BlockNodeView(
                                child,
                                theme,
                                highlighter,
                                isActiveStreamingBlock,
                                streamingEffect,
                                revealGranularity,
                                revealConfig,
                                streamingTimeSeconds,
                            )
                        }
                    }
                }
            }
        }
        is BlockNode.Table -> Column(modifier = Modifier.fillMaxWidth().background(Color.Transparent)) {
            fun rowText(row: io.github.sigkitten.hairball.core.MarkdownTableRow) =
                row.cells.joinToString(" | ") { it.content.joinToString("") { inline -> inline.plainText } }
            Text(
                applyStreamingEffect(
                    AnnotatedString(rowText(node.head)),
                    streamingEffect,
                    revealGranularity,
                    revealConfig,
                    isActiveStreamingBlock,
                    streamingTimeSeconds,
                    theme.foregroundColor,
                ),
                style = theme.bodyTextStyle.copy(fontWeight = FontWeight.SemiBold),
            )
            node.body.forEach { row ->
                Text(
                    applyStreamingEffect(
                        AnnotatedString(rowText(row)),
                        streamingEffect,
                        revealGranularity,
                        revealConfig,
                        isActiveStreamingBlock,
                        streamingTimeSeconds,
                        theme.foregroundColor,
                    ),
                    style = theme.bodyTextStyle,
                )
            }
        }
        is BlockNode.ThematicBreak -> Box(modifier = Modifier.fillMaxWidth().background(Color.Gray).padding(vertical = 1.dp))
        is BlockNode.HtmlBlock -> Text(node.content, style = theme.bodyTextStyle)
        is BlockNode.CustomBlock -> Text(node.content, style = theme.codeBlock.textStyle)
        is BlockNode.LatexBlock -> Text(node.content, style = theme.codeBlock.textStyle)
        is BlockNode.BlockDirective -> Column(verticalArrangement = Arrangement.spacedBy(theme.paragraphSpacingDp.dp)) {
            Text("@${node.name}", style = MaterialTheme.typography.labelMedium)
            node.children.forEach { child ->
                BlockNodeView(
                    child,
                    theme,
                    highlighter,
                    isActiveStreamingBlock,
                    streamingEffect,
                    revealGranularity,
                    revealConfig,
                    streamingTimeSeconds,
                )
            }
        }
    }
}

@Composable
fun StreamingMarkdownContentView(
    renderer: StreamingMarkdownRenderer,
    modifier: Modifier = Modifier,
    theme: MarkdownTheme = MarkdownTheme.Default,
    streamingEffect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    revealConfig: TokenRevealConfig = TokenRevealConfig.Default,
) {
    val blocks by renderer.identifiedBlocks.collectAsState()
    val isFinished by renderer.isFinished.collectAsState()
    val isEmpty by renderer.isEmpty.collectAsState()
    val streamingTimeSeconds = remember { mutableFloatStateOf(0f) }
    val revealDriver = remember { SmoothRevealDriver() }
    var didSeedReveal by remember(renderer) { mutableStateOf(false) }
    val totalDocumentLength = remember(blocks) { blocks.sumOf { blockPlainTextLength(it.block) } }

    LaunchedEffect(isFinished, streamingEffect, revealConfig.isEnabled) {
        if (isFinished || (!revealConfig.isEnabled && streamingEffect == null)) {
            return@LaunchedEffect
        }
        while (!renderer.isFinished.value) {
            delay(16)
            streamingTimeSeconds.floatValue += 0.016f
        }
    }

    LaunchedEffect(totalDocumentLength, isEmpty, revealConfig.duration, revealConfig.mode, revealConfig.isEnabled) {
        if (isEmpty && totalDocumentLength == 0) {
            didSeedReveal = false
            revealDriver.snapTo(0.0)
            return@LaunchedEffect
        }

        if (!revealConfig.isEnabled) {
            revealDriver.snapTo(totalDocumentLength.toDouble())
            didSeedReveal = true
            return@LaunchedEffect
        }

        revealDriver.timeConstant = revealConfig.duration
        revealDriver.linearMode = revealConfig.mode == TokenRevealMode.Linear

        if (!didSeedReveal) {
            val total = totalDocumentLength.toDouble()
            val snapPoint = if (!isEmpty && total > 0) max(total - 1.0, 0.0) else 0.0
            revealDriver.snapTo(snapPoint)
            didSeedReveal = true
        }

        revealDriver.setTarget(totalDocumentLength.toDouble())
    }

    LaunchedEffect(revealDriver.hasCaughtUp, revealConfig.isEnabled, isFinished, totalDocumentLength) {
        if (!revealConfig.isEnabled) {
            return@LaunchedEffect
        }
        while (!revealDriver.hasCaughtUp) {
            delay(16)
            revealDriver.tick()
        }
    }

    val usesCursorReveal = revealConfig.isEnabled && (!isFinished || !revealDriver.hasCaughtUp)
    val blockComplete = isFinished && revealDriver.hasCaughtUp

    if (usesCursorReveal) {
        CursorRevealBlocksView(
            blocks = blocks,
            cursor = revealDriver.smoothPosition,
            modifier = modifier,
            theme = theme,
            streamingEffect = streamingEffect,
            revealGranularity = revealGranularity,
            streamingTimeSeconds = streamingTimeSeconds.floatValue,
            blockComplete = blockComplete,
        )
    } else {
        MarkdownBlocksView(
            blocks = blocks,
            modifier = modifier,
            theme = theme,
            streamingEffect = streamingEffect,
            revealGranularity = revealGranularity,
            revealConfig = revealConfig,
            streamingTimeSeconds = streamingTimeSeconds.floatValue,
            streamFinished = isFinished,
        )
    }
}

@Composable
fun ChatMarkdownMessageView(
    role: ChatRole,
    renderer: StreamingMarkdownRenderer,
    modifier: Modifier = Modifier,
) {
    val theme = when (role) {
        ChatRole.Assistant -> MarkdownTheme.AssistantBubble
        ChatRole.User -> MarkdownTheme.UserBubble
    }
    StreamingMarkdownContentView(renderer = renderer, modifier = modifier, theme = theme)
}

enum class ChatRole {
    Assistant,
    User,
}

@Composable
private fun CursorRevealBlocksView(
    blocks: List<IdentifiedBlock>,
    cursor: Double,
    modifier: Modifier = Modifier,
    theme: MarkdownTheme = MarkdownTheme.Default,
    streamingEffect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    streamingTimeSeconds: Float = 0f,
    blockComplete: Boolean = false,
) {
    val offsets = remember(blocks) { cumulativeOffsets(blocks.map { blockPlainTextLength(it.block) }) }
    val canShortcut = revealGranularity == RevealGranularity.Character

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(theme.paragraphSpacingDp.dp),
    ) {
        blocks.forEachIndexed { index, item ->
            val start = offsets[index]
            val end = start + blockPlainTextLength(item.block)
            when {
                cursor >= end.toDouble() && blockComplete && canShortcut -> {
                    BlockNodeView(node = item.block, theme = theme)
                }
                cursor > start.toDouble() -> {
                    CursorRevealBlockView(
                        node = item.block,
                        revealPosition = cursor - start.toDouble(),
                        blockComplete = blockComplete,
                        theme = theme,
                        streamingEffect = streamingEffect,
                        revealGranularity = revealGranularity,
                        streamingTimeSeconds = streamingTimeSeconds,
                    )
                }
            }
        }
    }
}

@Composable
private fun CursorRevealBlockView(
    node: BlockNode,
    revealPosition: Double,
    blockComplete: Boolean,
    theme: MarkdownTheme,
    highlighter: CodeSyntaxHighlighter = DefaultCodeSyntaxHighlighter,
    streamingEffect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    streamingTimeSeconds: Float = 0f,
) {
    when (node) {
        is BlockNode.Heading -> {
            val style = theme.headingStyleSet[node.level]
            StreamingAttributedText(
                attributedString = buildInlineAnnotatedString(node.content, theme),
                revealPosition = revealPosition,
                blockComplete = blockComplete,
                textStyle = style.textStyle,
                textColor = if (style.color != Color.Unspecified) style.color else theme.foregroundColor,
                modifier = Modifier.fillMaxWidth(),
                effect = streamingEffect,
                revealGranularity = revealGranularity,
                streamingTimeSeconds = streamingTimeSeconds,
            )
        }
        is BlockNode.Paragraph -> StreamingAttributedText(
            attributedString = buildInlineAnnotatedString(node.content, theme),
            revealPosition = revealPosition,
            blockComplete = blockComplete,
            textStyle = theme.bodyTextStyle,
            textColor = theme.foregroundColor,
            effect = streamingEffect,
            revealGranularity = revealGranularity,
            streamingTimeSeconds = streamingTimeSeconds,
        )
        is BlockNode.CodeBlock -> StreamingAttributedText(
            attributedString = highlighter.highlightCode(node.content.trimEnd('\n'), node.language),
            revealPosition = revealPosition,
            blockComplete = blockComplete,
            textStyle = theme.codeBlock.textStyle,
            textColor = theme.codeBlock.textColor,
            modifier = Modifier
                .fillMaxWidth()
                .background(theme.codeBlock.backgroundColor)
                .padding(horizontal = theme.codeBlock.horizontalPaddingDp.dp, vertical = theme.codeBlock.verticalPaddingDp.dp)
                .horizontalScroll(rememberScrollState()),
            effect = streamingEffect,
            revealGranularity = revealGranularity,
            streamingTimeSeconds = streamingTimeSeconds,
            preserveExistingColors = true,
        )
        is BlockNode.BlockQuote -> Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(theme.blockquote.backgroundColor)
                .padding(start = theme.blockquote.borderWidthDp.dp),
        ) {
            CursorRevealChildrenView(
                children = node.children,
                cursor = revealPosition,
                blockComplete = blockComplete,
                theme = theme,
                highlighter = highlighter,
                streamingEffect = streamingEffect,
                revealGranularity = revealGranularity,
                streamingTimeSeconds = streamingTimeSeconds,
            )
        }
        is BlockNode.UnorderedList -> CursorRevealListView(
            orderedStartIndex = null,
            items = node.items,
            cursor = revealPosition,
            blockComplete = blockComplete,
            theme = theme,
            highlighter = highlighter,
            streamingEffect = streamingEffect,
            revealGranularity = revealGranularity,
            streamingTimeSeconds = streamingTimeSeconds,
        )
        is BlockNode.OrderedList -> CursorRevealListView(
            orderedStartIndex = node.startIndex,
            items = node.items,
            cursor = revealPosition,
            blockComplete = blockComplete,
            theme = theme,
            highlighter = highlighter,
            streamingEffect = streamingEffect,
            revealGranularity = revealGranularity,
            streamingTimeSeconds = streamingTimeSeconds,
        )
        else -> BlockNodeView(node = node, theme = theme, highlighter = highlighter)
    }
}

@Composable
private fun CursorRevealChildrenView(
    children: List<BlockNode>,
    cursor: Double,
    blockComplete: Boolean,
    theme: MarkdownTheme,
    highlighter: CodeSyntaxHighlighter,
    streamingEffect: StreamingTextEffect?,
    revealGranularity: RevealGranularity,
    streamingTimeSeconds: Float,
) {
    val offsets = remember(children) { cumulativeOffsets(children.map(::blockPlainTextLength)) }
    val canShortcut = revealGranularity == RevealGranularity.Character

    Column(verticalArrangement = Arrangement.spacedBy(theme.paragraphSpacingDp.dp)) {
        children.forEachIndexed { index, child ->
            val start = offsets[index]
            val end = start + blockPlainTextLength(child)
            when {
                cursor >= end.toDouble() && blockComplete && canShortcut -> {
                    BlockNodeView(node = child, theme = theme, highlighter = highlighter)
                }
                cursor > start.toDouble() -> {
                    CursorRevealBlockView(
                        node = child,
                        revealPosition = cursor - start.toDouble(),
                        blockComplete = blockComplete,
                        theme = theme,
                        highlighter = highlighter,
                        streamingEffect = streamingEffect,
                        revealGranularity = revealGranularity,
                        streamingTimeSeconds = streamingTimeSeconds,
                    )
                }
            }
        }
    }
}

@Composable
private fun CursorRevealListView(
    orderedStartIndex: Int?,
    items: List<io.github.sigkitten.hairball.core.ListItem>,
    cursor: Double,
    blockComplete: Boolean,
    theme: MarkdownTheme,
    highlighter: CodeSyntaxHighlighter,
    streamingEffect: StreamingTextEffect?,
    revealGranularity: RevealGranularity,
    streamingTimeSeconds: Float,
) {
    val offsets = remember(items) {
        cumulativeOffsets(items.map { item -> item.children.sumOf(::blockPlainTextLength) })
    }
    val spacing = theme.list.itemSpacingDp.dp
    val canShortcut = revealGranularity == RevealGranularity.Character

    Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
        items.forEachIndexed { index, item ->
            val start = offsets[index]
            val end = start + item.children.sumOf(::blockPlainTextLength)
            if (cursor <= start.toDouble()) {
                return@forEachIndexed
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = when {
                        orderedStartIndex != null -> "${orderedStartIndex + index}."
                        item.checkbox == CheckboxState.Checked -> theme.list.checkboxCheckedSymbol
                        item.checkbox == CheckboxState.Unchecked -> theme.list.checkboxUncheckedSymbol
                        else -> theme.list.bulletMarker.marker
                    },
                    style = theme.bodyTextStyle,
                )
                Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
                    if (cursor >= end.toDouble() && blockComplete && canShortcut) {
                        item.children.forEach { child ->
                            BlockNodeView(node = child, theme = theme, highlighter = highlighter)
                        }
                    } else {
                        CursorRevealChildrenView(
                            children = item.children,
                            cursor = cursor - start.toDouble(),
                            blockComplete = blockComplete,
                            theme = theme,
                            highlighter = highlighter,
                            streamingEffect = streamingEffect,
                            revealGranularity = revealGranularity,
                            streamingTimeSeconds = streamingTimeSeconds,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StreamingAttributedText(
    attributedString: AnnotatedString,
    revealPosition: Double,
    blockComplete: Boolean,
    textStyle: androidx.compose.ui.text.TextStyle,
    textColor: Color,
    modifier: Modifier = Modifier,
    effect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    streamingTimeSeconds: Float = 0f,
    preserveExistingColors: Boolean = false,
) {
    val totalGlyphs = attributedString.text.length
    val frame = computeEffectFrame(
        text = attributedString.text,
        glyphCount = totalGlyphs,
        revealedCount = revealPosition.toInt(),
        granularity = revealGranularity,
        blockComplete = blockComplete,
        time = streamingTimeSeconds.toDouble(),
    )

    EffectRenderedText(
        attributedString = attributedString,
        revealedCount = frame.revealedCount,
        settledCount = frame.settledCount,
        textStyle = textStyle,
        textColor = textColor,
        modifier = modifier,
        effect = effect,
        streamingTimeSeconds = streamingTimeSeconds,
        preserveExistingColors = preserveExistingColors,
    )
}

private fun cumulativeOffsets(lengths: List<Int>): List<Int> {
    var running = 0
    return buildList {
        lengths.forEach { length ->
            add(running)
            running += length
        }
    }
}

private fun buildInlineAnnotatedString(
    content: List<InlineNode>,
    theme: MarkdownTheme,
): AnnotatedString = buildAnnotatedString {
    content.forEach { inline ->
        when (inline) {
            is InlineNode.Text -> append(inline.value)
            is InlineNode.Emphasis -> withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(buildInlineAnnotatedString(inline.children, theme)) }
            is InlineNode.Strong -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(buildInlineAnnotatedString(inline.children, theme)) }
            is InlineNode.Strikethrough -> withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) { append(buildInlineAnnotatedString(inline.children, theme)) }
            is InlineNode.InlineCode -> withStyle(
                theme.inlineCode.spanStyle.copy(
                    background = theme.inlineCode.backgroundColor,
                    color = theme.inlineCode.textColor,
                ),
            ) { append(inline.value) }
            is InlineNode.Link -> withStyle(
                SpanStyle(
                    color = theme.link.color,
                    textDecoration = if (theme.link.underline) TextDecoration.Underline else TextDecoration.None,
                ),
            ) { append(buildInlineAnnotatedString(inline.children, theme)) }
            is InlineNode.Image -> append(inline.children.joinToString("") { it.plainText })
            is InlineNode.SoftBreak -> append(if (theme.softBreakMode == SoftBreakMode.Space) " " else "\n")
            is InlineNode.HardBreak, is InlineNode.LineBreak -> append("\n")
            is InlineNode.InlineHtml -> append(inline.value)
            is InlineNode.Latex -> append(inline.content)
            is InlineNode.Citation -> withStyle(SpanStyle(color = theme.citation.textColor, background = theme.citation.backgroundColor)) {
                append(inline.title ?: "[${inline.index}]")
            }
            is InlineNode.CustomInline -> append(inline.content)
        }
    }
}

private fun renderInline(
    content: List<InlineNode>,
    theme: MarkdownTheme,
    effect: StreamingTextEffect? = null,
    revealGranularity: RevealGranularity = RevealGranularity.Character,
    revealConfig: TokenRevealConfig = TokenRevealConfig.Disabled,
    isActiveStreamingBlock: Boolean = false,
    streamingTimeSeconds: Float = 0f,
): AnnotatedString {
    val base = buildInlineAnnotatedString(content, theme)
    return applyStreamingEffect(
        base = base,
        effect = effect,
        revealGranularity = revealGranularity,
        revealConfig = revealConfig,
        isActiveStreamingBlock = isActiveStreamingBlock,
        streamingTimeSeconds = streamingTimeSeconds,
        baseColor = theme.foregroundColor,
    )
}

private fun applyStreamingEffect(
    base: AnnotatedString,
    effect: StreamingTextEffect?,
    revealGranularity: RevealGranularity,
    revealConfig: TokenRevealConfig,
    isActiveStreamingBlock: Boolean,
    streamingTimeSeconds: Float,
    baseColor: Color,
    preserveExistingColors: Boolean = false,
): AnnotatedString {
    if (!isActiveStreamingBlock || !revealConfig.isEnabled || base.text.isEmpty()) {
        return base
    }

    val activeStart = computeActiveStart(
        text = base.text,
        revealGranularity = revealGranularity,
        revealConfig = revealConfig,
    )
    val lastIndex = base.text.lastIndex
    if (activeStart > lastIndex) {
        return base
    }

    return buildAnnotatedString {
        append(base)

        for (index in activeStart..lastIndex) {
            val relative = if (lastIndex == activeStart) 1f else (index - activeStart).toFloat() / (lastIndex - activeStart).toFloat()
            addStyle(
                styleForEffect(
                    effect = effect,
                    relative = relative,
                    index = index,
                    isCursor = index == lastIndex,
                    timeSeconds = streamingTimeSeconds,
                    baseColor = baseColor,
                    preserveExistingColors = preserveExistingColors,
                ),
                start = index,
                end = index + 1,
            )
        }
    }
}

private fun computeActiveStart(
    text: String,
    revealGranularity: RevealGranularity,
    revealConfig: TokenRevealConfig,
): Int {
    val trail = when (revealGranularity) {
        RevealGranularity.Character -> {
            val base = if (revealConfig.mode == TokenRevealMode.Continuous) 18 else 10
            max(4, (revealConfig.duration * base).roundToInt())
        }
        RevealGranularity.Block -> return 0
        RevealGranularity.Line -> {
            val lineStart = text.lastIndexOf('\n').let { if (it == -1) 0 else it + 1 }
            return lineStart
        }
        is RevealGranularity.Chunk -> revealGranularity.size.coerceAtLeast(2)
    }
    return (text.length - trail).coerceAtLeast(0)
}

private fun styleForEffect(
    effect: StreamingTextEffect?,
    relative: Float,
    index: Int,
    isCursor: Boolean,
    timeSeconds: Float,
    baseColor: Color,
    preserveExistingColors: Boolean,
): SpanStyle {
    val defaultColor = baseColor.takeUnless { it == Color.Unspecified } ?: Color.White
    val alpha = (0.22f + (relative * 0.78f)).coerceIn(0f, 1f)
    val pulse = ((sin((timeSeconds * 7f) + index) + 1f) * 0.5f)

    fun withColor(color: Color, extra: SpanStyle = SpanStyle()): SpanStyle {
        return extra.merge(
            SpanStyle(
                color = if (preserveExistingColors) Color.Unspecified else color,
            ),
        )
    }

    return when (effect) {
        is GlowCursorEffect -> withColor(
            if (isCursor) Color(0xFF8BE9FD) else defaultColor.copy(alpha = alpha),
            SpanStyle(
                background = if (isCursor) Color(0x332FE4FF) else Color.Transparent,
                fontWeight = if (isCursor) FontWeight.Bold else null,
            ),
        )
        is WaveRevealEffect -> withColor(
            defaultColor.copy(alpha = alpha),
            SpanStyle(
                baselineShift = BaselineShift(((sin(timeSeconds * 10f + index * 0.8f) * 0.45f).toFloat())),
            ),
        )
        is FireTrailEffect -> withColor(
            lerpColor(Color(0xFFFF8A3D), Color(0xFFFFD166), relative).copy(alpha = alpha),
            SpanStyle(fontWeight = if (isCursor) FontWeight.Bold else null),
        )
        is SparkleEffect -> withColor(
            defaultColor.copy(alpha = alpha),
            SpanStyle(
                background = if (((index + (timeSeconds * 20f).roundToInt()) % 5) == 0) Color(0x44FFE082) else Color.Transparent,
                fontWeight = if (isCursor) FontWeight.Bold else null,
            ),
        )
        is RainbowEffect, is NyanCatEffect -> withColor(
            rainbowColor(index, timeSeconds).copy(alpha = alpha),
            SpanStyle(fontWeight = if (isCursor) FontWeight.Bold else null),
        )
        is CombinedEffect -> withColor(
            rainbowColor(index, timeSeconds).copy(alpha = alpha),
            SpanStyle(
                baselineShift = BaselineShift(((sin(timeSeconds * 12f + index) * 0.35f).toFloat())),
                background = if (isCursor) Color(0x33FFFFFF) else Color.Transparent,
                fontWeight = if (isCursor) FontWeight.Bold else null,
            ),
        )
        is ExplosionEffect -> withColor(
            lerpColor(Color(0xFFFF5D73), Color(0xFFFFC857), relative).copy(alpha = alpha),
            SpanStyle(
                baselineShift = BaselineShift(((0.18f * pulse) - 0.05f)),
                fontWeight = FontWeight.Bold,
            ),
        )
        is MatrixDecodeEffect -> withColor(
            lerpColor(Color(0xFF4ADE80), Color(0xFFC7F9CC), relative).copy(alpha = alpha),
            SpanStyle(
                fontFamily = FontFamily.Monospace,
                background = if (isCursor) Color(0x3316A34A) else Color.Transparent,
            ),
        )
        is PhosphorCrtEffect -> withColor(
            lerpColor(Color(0xFF7CFC9A), Color(0xFFD7FFD9), relative).copy(alpha = alpha),
            SpanStyle(
                background = if (isCursor) Color(0x2215FF9B) else Color.Transparent,
            ),
        )
        is ShockwaveEffect -> withColor(
            lerpColor(Color(0xFFA78BFA), Color(0xFFFFFFFF), pulse).copy(alpha = alpha),
            SpanStyle(fontWeight = if (relative > 0.7f) FontWeight.Bold else null),
        )
        is FadeEdgeEffect, null -> withColor(
            defaultColor.copy(alpha = alpha),
            SpanStyle(background = if (isCursor) Color(0x22FFFFFF) else Color.Transparent),
        )
        else -> withColor(defaultColor.copy(alpha = alpha))
    }
}

private fun lerpColor(start: Color, end: Color, t: Float): Color {
    val clamped = t.coerceIn(0f, 1f)
    return Color(
        red = start.red + ((end.red - start.red) * clamped),
        green = start.green + ((end.green - start.green) * clamped),
        blue = start.blue + ((end.blue - start.blue) * clamped),
        alpha = start.alpha + ((end.alpha - start.alpha) * clamped),
    )
}

private fun rainbowColor(index: Int, timeSeconds: Float): Color {
    val palette = listOf(
        Color(0xFFFF5F6D),
        Color(0xFFFFC371),
        Color(0xFF47D16C),
        Color(0xFF4FC3F7),
        Color(0xFF7C4DFF),
    )
    val offset = ((timeSeconds * 8f).roundToInt() + index) % palette.size
    return palette[offset]
}
