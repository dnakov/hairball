import SwiftUI
import Hairball
import HairballUI

struct AllMarkdownTypesView: View {
    var body: some View {
        ScrollView {
            MarkdownView(Self.markdown, processors: [
                AutoLinkTransformer(),
                CitationProcessor(),
                LatexTransformer(),
            ])
            .padding()
        }
        .navigationTitle("All Markdown Types")
    }

    static let markdown = """
    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

    ---

    ## Paragraphs

    This is a paragraph with **bold**, *italic*, ***bold italic***, ~~strikethrough~~, and `inline code`.

    A second paragraph. Hard break at end:\u{0020}\u{0020}
    This continues after it.

    ## Links and Images

    [Example link](https://example.com) and an auto-link: https://github.com

    ![Sample image](https://picsum.photos/600/200 "Random photo")

    ## Block Quotes

    > A simple block quote with **formatting**.
    >
    > > Nested quote inside.

    ## Unordered Lists

    - First item
    - Second with **bold**
      - Nested A
      - Nested B
    - Third item

    ## Ordered Lists

    1. First
    2. Second
       1. Nested ordered
       2. Another nested
    3. Third

    ## Task Lists

    - [x] Completed task
    - [x] Another done
    - [ ] Pending task
    - [ ] Another pending

    ## Code Blocks

    ```swift
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0

        var body: some View {
            VStack {
                Text("Count: \\(count)")
                    .font(.largeTitle)
                Button("Increment") {
                    count += 1
                }
            }
        }
    }
    ```

    ```python
    def fibonacci(n):
        if n <= 1:
            return n
        return fibonacci(n - 1) + fibonacci(n - 2)

    print([fibonacci(i) for i in range(10)])
    ```

    ```json
    {
        "name": "Hairball",
        "version": "1.0.0",
        "features": ["parsing", "rendering", "streaming"]
    }
    ```

    Plain code block:

    ```
    No language specified — just monospace text.
    ```

    ## Tables

    | Feature | Status | Priority |
    |---------|:------:|-------:|
    | Parsing | Done | High |
    | Rendering | Done | High |
    | Streaming | Done | Medium |
    | Theming | Done | Low |

    ## Thematic Breaks

    Above the break.

    ---

    Below the break.

    ***

    Another style.

    ## HTML Block

    <div style="color: red;">
    Raw HTML block content.
    </div>

    ## LaTeX

    Inline: $E = mc^2$ and $\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$

    Display:

    $$
    \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
    $$

    ## Citations

    Footnote style[^1] and another[^2].

    CJK bracket style\u{3010}3\u{2020}methodology\u{3011}.

    ## Complex Nesting

    > ### Quoted Heading
    >
    > 1. Quoted list item with `code`
    > 2. Another with **bold** and *italic*
    >
    > > Deep nested quote

    ## Emphasis Combos

    **~~bold strikethrough~~** and *~~italic strikethrough~~* and ***~~everything~~***

    ---

    That covers every markdown type Hairball supports!
    """
}
