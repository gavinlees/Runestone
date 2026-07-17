import CoreGraphics
import Foundation

extension NSAttributedString.Key {
    static let isBold = NSAttributedString.Key("runestone_isBold")
    static let isItalic = NSAttributedString.Key("runestone_isItalic")
}

struct LineSyntaxHiglighterSetAttributesResult {
    let isSizingInvalid: Bool
}

final class LineSyntaxHighlighterInput {
    let attributedString: NSMutableAttributedString
    let byteRange: ByteRange
    /// Zero-based line number. Carried so a highlighter can identify the line
    /// without mapping `byteRange` (UTF-8 offsets) back through the line
    /// manager — see `CustomLanguageMode`.
    let lineIndex: Int
    /// UTF-16 offset of the line's first character within the document.
    let lineLocation: Int

    init(
        attributedString: NSMutableAttributedString,
        byteRange: ByteRange,
        lineIndex: Int = 0,
        lineLocation: Int = 0
    ) {
        self.attributedString = attributedString
        self.byteRange = byteRange
        self.lineIndex = lineIndex
        self.lineLocation = lineLocation
    }
}

protocol LineSyntaxHighlighter: AnyObject {
    typealias AsyncCallback = (Result<Void, Error>) -> Void
    var theme: Theme { get set }
    var canHighlight: Bool { get }
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput)
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback)
    func cancel()
}
