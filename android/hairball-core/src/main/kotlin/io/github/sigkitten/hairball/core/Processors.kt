package io.github.sigkitten.hairball.core

interface MarkdownProcessor {
    fun process(document: Document): Document
}

class CompositeProcessor(
    private val processors: List<MarkdownProcessor>,
) : MarkdownProcessor {
    override fun process(document: Document): Document =
        processors.fold(document) { current, processor -> processor.process(current) }
}

class DefaultMarkdownProcessor : MarkdownProcessor {
    override fun process(document: Document): Document =
        document.copy(blocks = document.blocks.mapNotNull(::processBlock))

    private fun processBlock(block: BlockNode): BlockNode? =
        when (block) {
            is BlockNode.DocumentBlock -> block.copy(children = block.children.mapNotNull(::processBlock)).takeIf { it.children.isNotEmpty() }
            is BlockNode.Heading -> block.copy(content = mergeTextNodes(normalizeInlines(block.content))).takeIf { it.content.isNotEmpty() }
            is BlockNode.Paragraph -> block.copy(content = mergeTextNodes(normalizeInlines(block.content))).takeIf { it.content.isNotEmpty() }
            is BlockNode.CodeBlock -> block.copy(content = block.content.trimEnd('\n') + "\n".takeIf { block.content.endsWith("\n") } .orEmpty())
            is BlockNode.BlockQuote -> block.copy(children = block.children.mapNotNull(::processBlock)).takeIf { it.children.isNotEmpty() }
            is BlockNode.OrderedList -> block.copy(items = block.items.mapNotNull(::processListItem)).takeIf { it.items.isNotEmpty() }
            is BlockNode.UnorderedList -> block.copy(items = block.items.mapNotNull(::processListItem)).takeIf { it.items.isNotEmpty() }
            is BlockNode.Table -> block.copy(
                head = processTableRow(block.head),
                body = block.body.map(::processTableRow),
            )
            is BlockNode.HtmlBlock -> block.takeIf { it.content.isNotBlank() }
            is BlockNode.LatexBlock -> block.takeIf { it.content.isNotBlank() }
            is BlockNode.BlockDirective -> block.copy(children = block.children.mapNotNull(::processBlock))
            else -> block
        }

    private fun processListItem(item: ListItem): ListItem? =
        item.copy(children = item.children.mapNotNull(::processBlock)).takeIf { it.children.isNotEmpty() }

    private fun processTableRow(row: MarkdownTableRow): MarkdownTableRow =
        MarkdownTableRow(row.cells.map { MarkdownTableCell(mergeTextNodes(normalizeInlines(it.content))) })

    private fun normalizeInlines(inlines: List<InlineNode>): List<InlineNode> =
        inlines.mapNotNull(::normalizeInline)

    private fun normalizeInline(inline: InlineNode): InlineNode? =
        when (inline) {
            is InlineNode.Text -> inline.value.replace(Regex("[ \\t]+"), " ").takeIf { it.isNotEmpty() }?.let(InlineNode::Text)
            is InlineNode.Emphasis -> inline.copy(children = mergeTextNodes(normalizeInlines(inline.children))).takeIf { it.children.isNotEmpty() }
            is InlineNode.Strong -> inline.copy(children = mergeTextNodes(normalizeInlines(inline.children))).takeIf { it.children.isNotEmpty() }
            is InlineNode.Strikethrough -> inline.copy(children = mergeTextNodes(normalizeInlines(inline.children))).takeIf { it.children.isNotEmpty() }
            is InlineNode.Link -> inline.copy(children = mergeTextNodes(normalizeInlines(inline.children)))
            is InlineNode.Image -> inline.copy(children = mergeTextNodes(normalizeInlines(inline.children)))
            else -> inline
        }

    private fun mergeTextNodes(inlines: List<InlineNode>): List<InlineNode> {
        val result = mutableListOf<InlineNode>()
        val pending = StringBuilder()
        fun flush() {
            if (pending.isNotEmpty()) {
                result += InlineNode.Text(pending.toString())
                pending.clear()
            }
        }
        for (inline in inlines) {
            if (inline is InlineNode.Text) {
                pending.append(inline.value)
            } else {
                flush()
                result += inline
            }
        }
        flush()
        return result
    }
}

class AutoLinkTransformer : MarkdownProcessor {
    override fun process(document: Document): Document =
        document.copy(blocks = document.blocks.map(::processBlock))

    private fun processBlock(block: BlockNode): BlockNode =
        when (block) {
            is BlockNode.DocumentBlock -> block.copy(children = block.children.map(::processBlock))
            is BlockNode.Heading -> block.copy(content = processInlines(block.content))
            is BlockNode.Paragraph -> block.copy(content = processInlines(block.content))
            is BlockNode.BlockQuote -> block.copy(children = block.children.map(::processBlock))
            is BlockNode.OrderedList -> block.copy(items = block.items.map(::processListItem))
            is BlockNode.UnorderedList -> block.copy(items = block.items.map(::processListItem))
            is BlockNode.Table -> block.copy(
                head = MarkdownTableRow(block.head.cells.map { MarkdownTableCell(processInlines(it.content)) }),
                body = block.body.map { row -> MarkdownTableRow(row.cells.map { MarkdownTableCell(processInlines(it.content)) }) },
            )
            is BlockNode.BlockDirective -> block.copy(children = block.children.map(::processBlock))
            else -> block
        }

    private fun processListItem(item: ListItem): ListItem =
        item.copy(children = item.children.map(::processBlock))

    private fun processInlines(inlines: List<InlineNode>): List<InlineNode> =
        inlines.flatMap(::processInline)

    private fun processInline(inline: InlineNode): List<InlineNode> =
        when (inline) {
            is InlineNode.Text -> extractLinks(inline.value)
            is InlineNode.Emphasis -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Strong -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Strikethrough -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Image -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Link, is InlineNode.InlineCode, is InlineNode.InlineHtml -> listOf(inline)
            else -> listOf(inline)
        }

    private fun extractLinks(text: String): List<InlineNode> {
        val regex = Regex("""(?:https?://|mailto:)[^\s<>\[\]()]*[^\s<>\[\]().,;:!?'")\]]""")
        val matches = regex.findAll(text).toList()
        if (matches.isEmpty()) return listOf(InlineNode.Text(text))

        val result = mutableListOf<InlineNode>()
        var last = 0
        for (match in matches) {
            if (last < match.range.first) {
                result += InlineNode.Text(text.substring(last, match.range.first))
            }
            val url = match.value
            val label = if (url.startsWith("mailto:")) url.removePrefix("mailto:") else url
            result += InlineNode.Link(destination = url, title = null, children = listOf(InlineNode.Text(label)))
            last = match.range.last + 1
        }
        if (last < text.length) {
            result += InlineNode.Text(text.substring(last))
        }
        return result
    }
}

class CitationProcessor : MarkdownProcessor {
    override fun process(document: Document): Document {
        val sources = linkedMapOf<Int, Pair<String?, String?>>()
        val blocks = document.blocks.map { processBlock(it, sources) }
        val metadata = document.metadata.toMutableMap()
        if (sources.isNotEmpty()) {
            metadata["citationCount"] = sources.size.toString()
            sources.forEach { (index, source) ->
                source.first?.let { metadata["citation.$index.url"] = it }
                source.second?.let { metadata["citation.$index.title"] = it }
            }
        }
        return Document(blocks = blocks, metadata = metadata)
    }

    private fun processBlock(block: BlockNode, sources: MutableMap<Int, Pair<String?, String?>>): BlockNode =
        when (block) {
            is BlockNode.DocumentBlock -> block.copy(children = block.children.map { processBlock(it, sources) })
            is BlockNode.Heading -> block.copy(content = processInlines(block.content, sources))
            is BlockNode.Paragraph -> block.copy(content = processInlines(block.content, sources))
            is BlockNode.BlockQuote -> block.copy(children = block.children.map { processBlock(it, sources) })
            is BlockNode.OrderedList -> block.copy(items = block.items.map { it.copy(children = it.children.map { child -> processBlock(child, sources) }) })
            is BlockNode.UnorderedList -> block.copy(items = block.items.map { it.copy(children = it.children.map { child -> processBlock(child, sources) }) })
            is BlockNode.Table -> block.copy(
                head = MarkdownTableRow(block.head.cells.map { MarkdownTableCell(processInlines(it.content, sources)) }),
                body = block.body.map { row -> MarkdownTableRow(row.cells.map { MarkdownTableCell(processInlines(it.content, sources)) }) },
            )
            is BlockNode.BlockDirective -> block.copy(children = block.children.map { processBlock(it, sources) })
            else -> block
        }

    private fun processInlines(inlines: List<InlineNode>, sources: MutableMap<Int, Pair<String?, String?>>): List<InlineNode> =
        inlines.flatMap { processInline(it, sources) }

    private fun processInline(inline: InlineNode, sources: MutableMap<Int, Pair<String?, String?>>): List<InlineNode> =
        when (inline) {
            is InlineNode.Text -> parseCitations(inline.value, sources)
            is InlineNode.Emphasis -> listOf(inline.copy(children = processInlines(inline.children, sources)))
            is InlineNode.Strong -> listOf(inline.copy(children = processInlines(inline.children, sources)))
            is InlineNode.Strikethrough -> listOf(inline.copy(children = processInlines(inline.children, sources)))
            is InlineNode.Link -> parseBracketCitationLink(inline, sources)?.let(::listOf)
                ?: listOf(inline.copy(children = processInlines(inline.children, sources)))
            is InlineNode.Image -> listOf(inline.copy(children = processInlines(inline.children, sources)))
            else -> listOf(inline)
        }

    private fun parseBracketCitationLink(
        link: InlineNode.Link,
        sources: MutableMap<Int, Pair<String?, String?>>,
    ): InlineNode.Citation? {
        val label = link.children.plainText
        val index = label.toIntOrNull() ?: return null
        sources[index] = link.destination to link.title
        return InlineNode.Citation(index = index, url = link.destination, title = link.title)
    }

    private fun parseCitations(text: String, sources: MutableMap<Int, Pair<String?, String?>>): List<InlineNode> {
        val matches = listOf(
            Regex("""\[\^(\d+)]""") to { groups: MatchResult.Destructured ->
                val index = groups.component1().toInt()
                InlineNode.Citation(index, null, null)
            },
            Regex("""【(\d+)†([^】]*)】""") to { groups: MatchResult.Destructured ->
                val index = groups.component1().toInt()
                val title = groups.component2().ifBlank { null }
                InlineNode.Citation(index, null, title)
            },
        )
        val result = mutableListOf<InlineNode>()
        var cursor = 0
        while (cursor < text.length) {
            val found = matches.mapNotNull { (regex, factory) ->
                regex.find(text, cursor)?.let { match -> Triple(match, factory(match.destructured), regex) }
            }.minByOrNull { it.first.range.first }

            if (found == null) {
                result += InlineNode.Text(text.substring(cursor))
                break
            }

            val (match, citation) = found
            if (match.range.first > cursor) {
                result += InlineNode.Text(text.substring(cursor, match.range.first))
            }
            citation as InlineNode.Citation
            sources[citation.index] = citation.url to citation.title
            result += citation
            cursor = match.range.last + 1
        }
        return result
    }
}

class LatexTransformer : MarkdownProcessor {
    override fun process(document: Document): Document =
        document.copy(blocks = document.blocks.flatMap(::processBlock))

    private fun processBlock(block: BlockNode): List<BlockNode> =
        when (block) {
            is BlockNode.DocumentBlock -> listOf(block.copy(children = block.children.flatMap(::processBlock)))
            is BlockNode.Heading -> listOf(block.copy(content = processInlines(block.content)))
            is BlockNode.Paragraph -> processParagraph(block.content)
            is BlockNode.BlockQuote -> listOf(block.copy(children = block.children.flatMap(::processBlock)))
            is BlockNode.OrderedList -> listOf(block.copy(items = block.items.map { it.copy(children = it.children.flatMap(::processBlock)) }))
            is BlockNode.UnorderedList -> listOf(block.copy(items = block.items.map { it.copy(children = it.children.flatMap(::processBlock)) }))
            is BlockNode.Table -> listOf(block.copy(
                head = MarkdownTableRow(block.head.cells.map { MarkdownTableCell(processInlines(it.content)) }),
                body = block.body.map { row -> MarkdownTableRow(row.cells.map { MarkdownTableCell(processInlines(it.content)) }) },
            ))
            is BlockNode.BlockDirective -> listOf(block.copy(children = block.children.flatMap(::processBlock)))
            else -> listOf(block)
        }

    private fun processParagraph(inlines: List<InlineNode>): List<BlockNode> {
        val fullText = inlines.joinToString(separator = "") {
            when (it) {
                is InlineNode.Text -> it.value
                is InlineNode.SoftBreak, is InlineNode.HardBreak, is InlineNode.LineBreak -> "\n"
                else -> ""
            }
        }.trim()

        if (fullText.startsWith("$$") && fullText.endsWith("$$") && fullText.length > 4) {
            return listOf(BlockNode.LatexBlock(fullText.removePrefix("$$").removeSuffix("$$").trim()))
        }
        if (fullText.startsWith("\\[") && fullText.endsWith("\\]") && fullText.length > 4) {
            return listOf(BlockNode.LatexBlock(fullText.removePrefix("\\[").removeSuffix("\\]").trim()))
        }
        return listOf(BlockNode.Paragraph(processInlines(inlines)))
    }

    private fun processInlines(inlines: List<InlineNode>): List<InlineNode> =
        inlines.flatMap(::processInline)

    private fun processInline(inline: InlineNode): List<InlineNode> =
        when (inline) {
            is InlineNode.Text -> parseLatex(inline.value)
            is InlineNode.Emphasis -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Strong -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Strikethrough -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Link -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.Image -> listOf(inline.copy(children = processInlines(inline.children)))
            is InlineNode.InlineCode, is InlineNode.Latex, is InlineNode.InlineHtml -> listOf(inline)
            else -> listOf(inline)
        }

    private fun parseLatex(text: String): List<InlineNode> {
        val result = mutableListOf<InlineNode>()
        var i = 0
        var textStart = 0

        fun flushText(end: Int) {
            if (textStart < end) {
                result += InlineNode.Text(text.substring(textStart, end))
            }
        }

        while (i < text.length) {
            if (text[i] == '\\' && i + 1 < text.length) {
                when (text[i + 1]) {
                    '$' -> {
                        flushText(i)
                        result += InlineNode.Text("$")
                        i += 2
                        textStart = i
                        continue
                    }
                    '(' -> {
                        val end = text.indexOf("\\)", startIndex = i + 2)
                        if (end > i + 2) {
                            flushText(i)
                            result += InlineNode.Latex(text.substring(i + 2, end))
                            i = end + 2
                            textStart = i
                            continue
                        }
                    }
                }
            }

            if (text[i] == '$' && (i + 1 >= text.length || text[i + 1] != '$')) {
                val end = text.indexOf('$', startIndex = i + 1)
                if (end > i + 1) {
                    flushText(i)
                    result += InlineNode.Latex(text.substring(i + 1, end))
                    i = end + 1
                    textStart = i
                    continue
                }
            }
            i += 1
        }

        flushText(text.length)
        return if (result.isEmpty()) listOf(InlineNode.Text(text)) else result
    }
}
