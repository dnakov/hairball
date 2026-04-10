# Hairball

A Swift markdown parsing and rendering library for iOS and macOS. Two targets:

- **Hairball** — parsing, AST, processors. No UI dependencies.
- **HairballUI** — SwiftUI rendering with theming, syntax highlighting (Highlightr), LaTeX (SwiftMath), and streaming support.

```swift
.package(url: "https://github.com/dnakov/hairball.git", from: "1.0.0")
```

Platforms: iOS 16+, macOS 13+

---

## Quick Start

```swift
import HairballUI

// Render a markdown string
MarkdownView("# Hello\n\nSome **bold** and *italic* text.")

// With processors
MarkdownView("Check $E=mc^2$ and https://example.com", processors: [
    LatexTransformer(),
    AutoLinkTransformer(),
    CitationProcessor(),
])

// With a theme
MarkdownView("# Styled")
    .markdownTheme(.assistantBubble)

// With syntax highlighting theme
MarkdownView("```swift\nlet x = 42\n```")
    .codeSyntaxHighlighter(HighlightrCodeSyntaxHighlighter(theme: "github-dark"))
```

---

## Rendering Layers

Four layers, from highest to lowest level of control:

### Layer 1: `MarkdownView` — highest level

Takes a string, parses it, renders it.

```swift
MarkdownView("# Title\n\nParagraph with **bold**.")
```

### Layer 2: `MarkdownDocumentView` — you own the document

You parse the markdown yourself. The view just renders.

```swift
let parser = MarkdownParser()
let doc = parser.parse(myMarkdown)

MarkdownDocumentView(document: doc)
```

### Layer 3: `MarkdownBlocksView` — you own the blocks and animation

You parse, identify blocks, and control streaming animation.

```swift
let blocks = IdentifiedBlock.identify(document.blocks)

MarkdownBlocksView(blocks: blocks, isStreaming: true)
    .tokenAnimator(FadeTokenAnimator())
    .tokenReveal(.init(duration: 0.15, mode: .continuous))
```

### Layer 4: `BlockNodeView` — you own everything

Render individual blocks with zero opinions from the library.

```swift
ForEach(IdentifiedBlock.identify(doc.blocks)) { item in
    BlockNodeView(node: item.block)
}
```

---

## Streaming

### Option A: Let Hairball manage the pipeline

```swift
@StateObject var renderer = StreamingMarkdownRenderer(
    processors: [LatexTransformer(), AutoLinkTransformer()],
    throttleInterval: 0.016
)

// View
StreamingMarkdownContentView(renderer: renderer)
    .tokenAnimator(FadeTokenAnimator())
    .tokenReveal(.init(duration: 0.15, mode: .continuous))

// Feed tokens
Task {
    for await token in myLLMStream {
        renderer.append(token)
    }
    renderer.finish()
}
```

### Option B: You handle streaming, Hairball renders

```swift
@State private var document = Document(blocks: [])
let parser = MarkdownParser()

MarkdownDocumentView(document: document, isStreaming: true)
    .tokenAnimator(FadeTokenAnimator())
    .tokenReveal(.default)

func onToken(_ token: String) {
    accumulated += token
    document = parser.parse(accumulated)
}
```

### Animation Control

All animation is app-controlled via environment modifiers. The library has no hardcoded animations.

**Token animator** — how individual characters appear:

```swift
.tokenAnimator(FadeTokenAnimator())    // opacity 0→1 (default)
.tokenAnimator(RevealTokenAnimator())  // left-to-right reveal
.tokenAnimator(InstantTokenAnimator()) // no animation

// Custom:
struct GlowAnimator: TokenAnimator {
    func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text {
        var f = fresh
        f.foregroundColor = foregroundColor.opacity(progress)
        f.backgroundColor = .yellow.opacity((1 - progress) * 0.3)
        if revealed.characters.isEmpty { return Text(f) }
        return Text(revealed) + Text(f)
    }
}
```

**Reveal config** — timing and mode:

```swift
.tokenReveal(TokenRevealConfig(
    duration: 0.15,       // smoothing constant / batch window
    mode: .continuous     // or .batched
))

// Presets
.tokenReveal(.fast)       // 80ms
.tokenReveal(.slow)       // 300ms
.tokenReveal(.disabled)   // no animation
.tokenReveal(.default)    // 150ms continuous
```

**Two reveal modes:**

- **Continuous** — a smooth cursor chases the stream at 60fps. `duration` is the smoothing time constant (lower = tighter tracking, higher = trailing effect). Set `throttleInterval` low (0.016) so the renderer feeds content as fast as possible.
- **Batched** — tokens are buffered into discrete batches. Each batch animates fully before the next starts. Set `throttleInterval` equal to `duration` so parse batches align with animation cycles.

**Block-level animation** — for new blocks appearing during streaming:

```swift
// Explicit (overrides auto-derivation from tokenReveal):
MarkdownBlocksView(
    blocks: blocks,
    isStreaming: true,
    blockAnimation: .easeOut(duration: 0.2),
    blockTransition: .opacity
)

// Or let the library derive it from tokenReveal config (default).
// When tokenReveal is enabled, new blocks fade in with matching timing.
// When disabled, no block animation.
```

### Streaming Architecture

```
tokens → StreamingMarkdownRenderer → Document → MarkdownBlocksView
              ↑ throttleInterval          ↑ tokenReveal config
              (content buffer)            (animation timing)
```

The renderer's `throttleInterval` controls how often tokens are parsed into blocks. The view's `tokenReveal` config controls how those blocks animate. For continuous mode, keep `throttleInterval` low. For batched mode, match them.

---

## Theming

Every element is configurable:

```swift
let theme = MarkdownTheme(
    bodyFont: .system(size: 15),
    foregroundColor: .white,
    paragraphSpacing: 10,
    codeBlock: CodeBlockStyle(
        backgroundColor: Color(white: 0.1),
        textColor: Color(white: 0.85),
        cornerRadius: 10
    ),
    blockquote: BlockquoteStyle(
        borderColor: .blue,
        borderWidth: 3,
        textColor: .gray
    ),
    table: TableStyle(
        headerBackground: Color(white: 0.15),
        backgroundStyle: .alternatingRows(even: Color(white: 0.08), odd: .clear)
    ),
    link: LinkStyle(color: .blue, underline: true)
)

MarkdownView("...")
    .markdownTheme(theme)
```

Built-in presets: `.default`, `.assistantBubble`, `.userBubble`, `.userBubblePending`

### Syntax highlighting themes

```swift
let highlighter = HighlightrCodeSyntaxHighlighter(theme: "atom-one-dark")

highlighter.setTheme("github")             // change at runtime
highlighter.availableThemes                 // ["atom-one-dark", "github", ...]

MarkdownView("...")
    .codeSyntaxHighlighter(highlighter)
```

---

## Custom Rendering

Replace the view for any block type:

```swift
struct MyProvider: MarkdownViewComponentProvider {
    func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        MyFancyCodeBlock(code: code, language: language)
    }

    func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        HeadingView(level: level, content: content)
    }
}

MarkdownView("...")
    .markdownComponentProvider(MyProvider())
```

Or replace just the code block renderer:

```swift
struct NeonCodeRenderer: CodeBlockRenderer {
    func makeBody(configuration: CodeBlockConfiguration) -> some View {
        Text(configuration.highlightedCode)
            .padding()
            .background(.black)
            .cornerRadius(12)
    }
}

MarkdownView("...")
    .codeBlockRenderer(NeonCodeRenderer())
```

---

## Processors

Transform the parsed AST before rendering:

| Processor | What it does |
|-----------|-------------|
| `LatexTransformer` | `$...$` to inline math, `$$...$$` to display math |
| `AutoLinkTransformer` | Raw URLs in text become tappable links |
| `CitationProcessor` | `[^1]` and `[1](url)` become citation nodes |
| `DefaultMarkdownProcessor` | Normalize whitespace, merge text nodes |

```swift
MarkdownView("...", processors: [
    AutoLinkTransformer(),
    LatexTransformer(),
    CitationProcessor(),
])
```

Write your own:

```swift
struct MyProcessor: MarkdownProcessor {
    func process(_ document: Document) -> Document {
        // Walk and transform the AST
    }
}
```

---

## AST Access

Parse markdown into a typed AST for programmatic use:

```swift
import Hairball

let parser = MarkdownParser()
let document = parser.parse("# Hello\n\n**bold** text")

for block in document.blocks {
    switch block {
    case .heading(let level, let content):
        print("H\(level): \(content)")
    case .paragraph(let content):
        for inline in content {
            switch inline {
            case .strong(let children): print("Bold: \(children)")
            case .text(let str): print("Text: \(str)")
            default: break
            }
        }
    default: break
    }
}
```

### Block types

`heading`, `paragraph`, `codeBlock`, `blockQuote`, `orderedList`, `unorderedList`, `table`, `thematicBreak`, `htmlBlock`, `latexBlock`, `blockDirective`, `customBlock`

### Inline types

`text`, `emphasis`, `strong`, `strikethrough`, `inlineCode`, `link`, `image`, `softBreak`, `hardBreak`, `lineBreak`, `inlineHTML`, `latex`, `citation`, `customInline`

---

## Building Documents Programmatically

```swift
let doc = Document(blocks: [
    .heading(level: 1, content: [.text("Title")]),
    .paragraph(content: [
        .text("Hello "),
        .strong(children: [.text("world")]),
    ]),
    .codeBlock(language: "swift", content: "let x = 42"),
    .unorderedList(tight: true, items: [
        ListItem(children: [.paragraph(content: [.text("Item 1")])], checkbox: .checked),
        ListItem(children: [.paragraph(content: [.text("Item 2")])], checkbox: .unchecked),
    ]),
])

MarkdownView(document: doc)
```

Or with the result builder:

```swift
MarkdownView {
    Heading(level: 1, "Title")
    Paragraph("Some text")
    CodeBlock(language: "swift", "let x = 42")
    if showOptional {
        Paragraph("Conditional content")
    }
}
```
