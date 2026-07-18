import Foundation

/// A syntax highlighter supplied by the host app, called once per line as the
/// line is laid out.
///
/// Runestone's built-in highlighting is tree-sitter only, and the seam that
/// vends a highlighter (`InternalLanguageMode.createLineSyntaxHighlighter()`)
/// is internal, so an app with its own highlighting engine has no way in. This
/// protocol is that way in.
///
/// The line's own attributed string is handed over directly, along with the
/// line's index and start offset, so an external per-line highlighter needs no
/// knowledge of Runestone's internal byte-offset representation.
public protocol LineHighlighter: AnyObject {
    /// Apply styling to one line by mutating `attributedString` in place.
    ///
    /// Called on the main thread as the line is laid out — only for lines in or
    /// near the viewport, so cost here scales with the viewport, not the
    /// document.
    ///
    /// - Parameters:
    ///   - attributedString: The line's own text, pre-populated with the
    ///     theme's default attributes. Mutate in place to style it.
    ///   - lineIndex: Zero-based line number within the document.
    ///   - lineLocation: UTF-16 offset of the line's first character within the
    ///     document. Add to a line-relative offset to get a document offset.
    func highlight(_ attributedString: NSMutableAttributedString, lineIndex: Int, lineLocation: Int)

    /// Notify the highlighter that the document changed, so it can update its
    /// own incremental model *before* the affected lines are re-laid out.
    ///
    /// Called synchronously on the main thread as part of the edit, once per
    /// edit. Offsets are document-absolute UTF-16 — the same representation
    /// `highlight(_:lineIndex:lineLocation:)` uses — so a host highlighter never
    /// has to touch Runestone's internal byte offsets.
    ///
    /// - Parameters:
    ///   - startUtf16: UTF-16 offset where the replaced range began.
    ///   - oldLengthUtf16: UTF-16 length of the text that was replaced.
    ///   - replacement: The text that now occupies the range (already applied to
    ///     the document).
    /// - Returns: Zero-based indices of every line whose styling may have
    ///   changed, *including* lines the edit did not touch textually (e.g. lines
    ///   recoloured by opening a fenced code block). Runestone re-highlights
    ///   exactly these lines in addition to the ones the edit structurally
    ///   changed. Return an empty array for a highlighter that recomputes lazily
    ///   inside `highlight(...)`.
    func applyEdit(startUtf16: Int, oldLengthUtf16: Int, replacement: String) -> [Int]
}

public extension LineHighlighter {
    /// Default: no explicit incremental update. Suits a highlighter that
    /// recomputes lazily when each line is laid out.
    func applyEdit(startUtf16: Int, oldLengthUtf16: Int, replacement: String) -> [Int] { [] }
}

/// Highlights text using a `LineHighlighter` supplied by the host app, instead
/// of tree-sitter.
///
/// Pass to `TextView.setLanguageMode(_:)`, or to `TextViewState`.
public final class CustomLanguageMode: LanguageMode {
    /// The host app's per-line highlighter.
    public let highlighter: LineHighlighter

    /// Creates a language mode that highlights via `highlighter`.
    public init(highlighter: LineHighlighter) {
        self.highlighter = highlighter
    }
}
