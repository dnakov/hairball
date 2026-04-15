import SwiftUI
import Hairball
import HairballUI

struct ProcessorPipelineView: View {
    @State private var enableAutoLink = true
    @State private var enableCitations = true
    @State private var enableLatex = true
    @State private var enableDefault = true

    private var processors: [any MarkdownProcessor] {
        var p: [any MarkdownProcessor] = []
        if enableDefault { p.append(DefaultMarkdownProcessor()) }
        if enableAutoLink { p.append(AutoLinkTransformer()) }
        if enableCitations { p.append(CitationProcessor()) }
        if enableLatex { p.append(LatexTransformer()) }
        return p
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Toggle("Default", isOn: $enableDefault)
                    Toggle("Auto-Link", isOn: $enableAutoLink)
                    Toggle("Citations", isOn: $enableCitations)
                    Toggle("LaTeX", isOn: $enableLatex)
                }
                .toggleStyle(.button)
                .padding()
            }

            Divider()

            ScrollView {
                MarkdownView(Self.content, processors: processors)
                    .padding()
            }
        }
        .navigationTitle("Processors")
    }

    static let content = """
    ## Processor Pipeline Demo

    ### Auto-Link Transformer
    Raw URLs become links: https://github.com/apple/swift-markdown

    ### Citation Processor
    Footnote[^1] and CJK bracket\u{3010}2\u{2020}source\u{3011} citations.

    ### LaTeX Transformer
    Inline $E = mc^2$ and display:

    $$
    \\nabla \\times \\mathbf{E} = -\\frac{\\partial \\mathbf{B}}{\\partial t}
    $$

    ### Default Processor
    Normalizes     extra   whitespace and merges text nodes.

    Toggle processors above to see their effects!
    """
}
