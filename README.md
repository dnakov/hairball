# Hairball

A Swift markdown parsing and rendering library for iOS and macOS. Two targets:

- **Hairball** — parsing, AST, processors. No UI dependencies.
- **HairballUI** — SwiftUI rendering with theming, syntax highlighting (Highlightr), LaTeX (SwiftMath), and streaming support.

```swift
.package(url: "https://github.com/user/hairball.git", from: "1.0.0")
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

Hairball has four rendering layers. Pick the one that matches how much control you need:

### Layer 1: `MarkdownView` — highest level

Takes a string, parses it, renders it. Zero configuration required.

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

MarkdownBlocksView(
    blocks: blocks,
    isStreaming: true,
    blockAnimation: .spring(duration: 0.3),
    blockTransition: .opacity
)
```

### Layer 4: `BlockNodeView` — you own everything

Render individual blocks with zero opinions from the library.

```swift
ForEach(IdentifiedBlock.identify(doc.blocks)) { item in
    BlockNodeView(node: item.block)
        .transition(.push(from: .bottom))
        .animation(.spring, value: item.id)
}
```

---

## Streaming

### Option A: Let Hairball handle it

```swift
@StateObject var renderer = StreamingMarkdownRenderer(
    processors: [LatexTransformer(), AutoLinkTransformer()],
    throttleInterval: 0.016,
    blockAnimation: .easeOut(duration: 0.2),
    blockTransition: .opacity
)

// View
StreamingMarkdownContentView(renderer: renderer)

// Feed tokens
Task {
    for await token in myLLMStream {
        renderer.append(token)
    }
    renderer.finish()
}
```

### Option B: You handle streaming, Hairball renders

If you already have your own streaming pipeline:

```swift
@State private var document = Document(blocks: [])
@State private var isStreaming = false

let parser = MarkdownParser()
let processors: [any MarkdownProcessor] = [LatexTransformer()]

// Your view
MarkdownDocumentView(
    document: document,
    isStreaming: isStreaming,
    blockAnimation: .easeOut(duration: 0.2),
    blockTransition: .opacity
)

// Your streaming loop — you control everything
func onToken(_ token: String) {
    accumulated += token
    var doc = parser.parse(accumulated)
    for p in processors { doc = p.process(doc) }
    document = doc
}

func onStreamEnd() {
    isStreaming = false
}
```

This gives you full control over:
- When to re-parse (every token? every 3 tokens? on newlines only?)
- What processors to run and when
- Animation timing
- Throttling strategy

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
// Use any Highlightr theme
let highlighter = HighlightrCodeSyntaxHighlighter(theme: "atom-one-dark")

// Change at runtime
highlighter.setTheme("github")

// List available themes
highlighter.availableThemes // ["atom-one-dark", "github", "monokai", ...]

MarkdownView("...")
    .codeSyntaxHighlighter(highlighter)
```

---

## Custom Rendering

Replace the view for any block type:

```swift
struct MyProvider: MarkdownViewComponentProvider {
    func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        // Your custom code block with whatever UI you want
        MyFancyCodeBlock(code: code, language: language)
    }

    // Return default views for everything else
    func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        HeadingView(level: level, content: content)
    }
    // ... other block types
}

MarkdownView("...")
    .markdownComponentProvider(MyProvider())
```

Or replace just the code block renderer:

```swift
struct NeonCodeRenderer: CodeBlockRenderer {
    func makeBody(configuration: CodeBlockConfiguration) -> some View {
        // configuration.code, configuration.language, configuration.highlightedCode, configuration.lineCount
        VStack {
            Text(configuration.highlightedCode)
                .padding()
        }
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

Chain them:

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

`document`, `heading`, `paragraph`, `codeBlock`, `blockQuote`, `orderedList`, `unorderedList`, `table`, `thematicBreak`, `htmlBlock`, `latexBlock`, `blockDirective`, `customBlock`

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
