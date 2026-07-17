import Foundation

/// Adapts a host-supplied `LineHighlighter` to Runestone's internal
/// highlighting seam. Modelled on `PlainTextInternalLanguageMode`: there is no
/// parse step and no syntax tree, because an external highlighter is assumed to
/// own its own parsing (incremental or otherwise) and to expose results
/// per-line.
///
/// Consequently the structural queries — syntax nodes, indent detection — return
/// the same neutral answers `PlainTextInternalLanguageMode` gives. An app
/// wanting tree-sitter's structural features should use `TreeSitterLanguageMode`
/// instead; this mode is for styling only.
final class CustomInternalLanguageMode: InternalLanguageMode {
    private let highlighter: LineHighlighter

    init(highlighter: LineHighlighter) {
        self.highlighter = highlighter
    }

    func parse(_ text: NSString) {}

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        completion(true)
    }

    func textDidChange(_ change: TextChange) -> LineChangeSet {
        // The host highlighter owns its own incremental update; returning an
        // empty change set leaves Runestone's own line invalidation (driven by
        // the edit itself) to decide what to re-highlight.
        LineChangeSet()
    }

    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        CustomLineSyntaxHighlighter(highlighter: highlighter)
    }

    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        nil
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int {
        0
    }

    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition,
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
        InsertLineBreakIndentStrategy(indentLevel: 0, insertExtraLineBreak: false)
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        .unknown
    }
}

/// Forwards Runestone's per-line highlight call to the host's `LineHighlighter`.
final class CustomLineSyntaxHighlighter: LineSyntaxHighlighter {
    var theme: Theme = DefaultTheme()
    var canHighlight: Bool {
        true
    }

    private let highlighter: LineHighlighter

    init(highlighter: LineHighlighter) {
        self.highlighter = highlighter
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        highlighter.highlight(
            input.attributedString,
            lineIndex: input.lineIndex,
            lineLocation: input.lineLocation)
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        // Synchronous: the host highlighter is called on the layout pass for
        // viewport-local lines. An async hop would show unstyled text first.
        syntaxHighlight(input)
        completion(.success(()))
    }

    func cancel() {}
}
