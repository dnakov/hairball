import SwiftUI

// MARK: - InteractiveTextAttachment Protocol

public protocol InteractiveTextAttachment: Identifiable {
    associatedtype Label: View
    associatedtype Detail: View

    var id: String { get }
    var displayText: String { get }

    @ViewBuilder func makeLabel() -> Label
    @ViewBuilder func makeDetail() -> Detail

    func onTap()
}

extension InteractiveTextAttachment {
    public func makeDetail() -> some View {
        EmptyView()
    }

    public func onTap() {}
}

// MARK: - CitationAttachment

public struct CitationAttachment: InteractiveTextAttachment {
    public let id: String
    public let index: Int
    public let url: String?
    public let title: String?
    public let displayText: String
    public var onTapHandler: ((CitationAttachment) -> Void)?

    public init(index: Int, url: String?, title: String?, onTapHandler: ((CitationAttachment) -> Void)? = nil) {
        self.id = "citation-\(index)"
        self.index = index
        self.url = url
        self.title = title
        self.displayText = title ?? url ?? "[\(index)]"
        self.onTapHandler = onTapHandler
    }

    public func makeLabel() -> some View {
        SwiftUI.Text(displayText)
            .font(.system(size: 11))
            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .frame(maxWidth: 180)
            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(red: 0.87, green: 0.87, blue: 0.87), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 2)
    }

    public func makeDetail() -> some View {
        EmptyView()
    }

    public func onTap() {
        onTapHandler?(self)
    }
}

// MARK: - AnyInteractiveTextAttachment

public struct AnyInteractiveTextAttachment: Identifiable {
    public let id: String
    public let displayText: String
    private let _makeLabel: () -> AnyView
    private let _makeDetail: () -> AnyView
    private let _onTap: () -> Void

    public init<A: InteractiveTextAttachment>(_ attachment: A) {
        self.id = attachment.id
        self.displayText = attachment.displayText
        self._makeLabel = { AnyView(attachment.makeLabel()) }
        self._makeDetail = { AnyView(attachment.makeDetail()) }
        self._onTap = { attachment.onTap() }
    }

    public func makeLabel() -> AnyView { _makeLabel() }
    public func makeDetail() -> AnyView { _makeDetail() }
    public func onTap() { _onTap() }
}
