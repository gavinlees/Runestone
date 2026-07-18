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
    private let stringView: StringView
    private let lineManager: LineManager

    init(highlighter: LineHighlighter, stringView: StringView, lineManager: LineManager) {
        self.highlighter = highlighter
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func parse(_ text: NSString) {}

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        completion(true)
    }

    func textDidChange(_ change: TextChange) -> LineChangeSet {
        // Hand the edit to the host highlighter in document-absolute UTF-16 —
        // ByteCount is UTF-16 units × 2, so `utf16Length` is an exact halving,
        // never a UTF-8 conversion. The replacement text is read back from the
        // already-updated document. The highlighter updates its own incremental
        // model and tells us every line whose styling may have moved (including
        // recoloured-but-untouched lines, e.g. below a newly-opened fence); we
        // mark those edited so Runestone re-runs the highlighter on them.
        // Structurally edited lines are covered by Runestone's own change set,
        // which is unioned with this one.
        let startUtf16 = change.byteRange.location.utf16Length
        let oldLengthUtf16 = change.byteRange.length.utf16Length
        let newLengthUtf16 = change.bytesAdded.utf16Length
        let replacement = stringView.substring(
            in: NSRange(location: startUtf16, length: newLengthUtf16)) ?? ""
        let affectedLines = highlighter.applyEdit(
            startUtf16: startUtf16,
            oldLengthUtf16: oldLengthUtf16,
            replacement: replacement)
        let changeSet = LineChangeSet()
        let lineCount = lineManager.lineCount
        for row in affectedLines where row >= 0 && row < lineCount {
            changeSet.markLineEdited(lineManager.line(atRow: row))
        }
        return changeSet
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
