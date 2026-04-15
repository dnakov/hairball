package io.github.sigkitten.hairball.core

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HairballCoreFixtureTests {
    private val mapper = jacksonObjectMapper()

    @Test
    fun parserMatchesCoreFixtureShape() {
        val fixture = readFixture("parser.json")["document"]
        val document = MarkdownParser().parse(
            """
            # Fixtures

            Paragraph with **bold**, `code`, [link](https://example.com), and task list:

            - [x] complete
            - [ ] pending

            | A | B |
            |---|---|
            | 1 | 2 |
            """.trimIndent(),
        )

        assertEquals(fixture["blocks"].size(), document.blocks.size)
        assertEquals("heading", fixture["blocks"][0]["type"].asText())
        assertEquals("unorderedList", fixture["blocks"][2]["type"].asText())
        assertEquals("table", fixture["blocks"][3]["type"].asText())
    }

    @Test
    fun processorsMatchFixtureExpectations() {
        val fixture = readFixture("processor.json")["document"]
        val parser = MarkdownParser()
        var document = parser.parse(
            """
            Visit https://example.com and cite [1](https://example.com "Example").

            Inline math ${'$'}E = mc^2${'$'} and footnote[^2].
            """.trimIndent(),
        )
        document = CompositeProcessor(listOf(AutoLinkTransformer(), CitationProcessor(), LatexTransformer())).process(document)

        assertEquals(fixture["metadata"]["citation.1.url"].asText(), document.metadata["citation.1.url"])
        assertEquals(fixture["metadata"]["citation.1.title"].asText(), document.metadata["citation.1.title"])
        val firstParagraph = document.blocks[0] as BlockNode.Paragraph
        assertTrue(firstParagraph.content.any { it is InlineNode.Citation && it.index == 1 })
    }

    @Test
    fun identifiedBlocksMatchFixtureIds() {
        val fixture = readFixture("identified_blocks.json")["identifiedBlocks"]
        val document = MarkdownParser().parse(
            """
            # Intro

            Paragraph one.

            Paragraph two with `inline code`.
            """.trimIndent(),
        )
        val identified = IdentifiedBlock.identify(document.blocks)
        assertEquals(fixture[0]["id"].asText(), identified[0].id)
        assertEquals(fixture[1]["id"].asText(), identified[1].id)
        assertEquals(fixture[2]["id"].asText(), identified[2].id)
    }

    @Test
    fun streamingFixtureRetainsTableStabilizationExpectation() {
        val fixture = readFixture("streaming.json")["table"]
        val parser = MarkdownParser()
        val document = parser.parse("Text\n| A | B |\n|---|---|")
        assertEquals(fixture[3]["rawBlockTypes"][1].asText(), document.blocks[1].typePrefixName())
    }

    private fun readFixture(name: String): JsonNode =
        mapper.readTree(java.io.File("../../spec/fixtures/$name"))

    private fun BlockNode.typePrefixName(): String =
        when (this) {
            is BlockNode.DocumentBlock -> "document"
            is BlockNode.Heading -> "heading"
            is BlockNode.Paragraph -> "paragraph"
            is BlockNode.CodeBlock -> "codeBlock"
            is BlockNode.BlockQuote -> "blockQuote"
            is BlockNode.OrderedList -> "orderedList"
            is BlockNode.UnorderedList -> "unorderedList"
            is BlockNode.Table -> "table"
            is BlockNode.ThematicBreak -> "thematicBreak"
            is BlockNode.HtmlBlock -> "htmlBlock"
            is BlockNode.CustomBlock -> "customBlock"
            is BlockNode.LatexBlock -> "latexBlock"
            is BlockNode.BlockDirective -> "blockDirective"
        }
}
