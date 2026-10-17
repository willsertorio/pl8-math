/// Cleans OCR text before parsing.
enum OCRText {
    /// Vision sometimes reads Latin letters as Cyrillic or Greek letters that look the same
    /// ("А." with a Cyrillic А — Fixtures 13/10). Swap them back to Latin.
    static func latinized(_ text: String) -> String {
        String(text.map { lookalikes[$0] ?? $0 })
    }

    private static let lookalikes: [Character: Character] = [
        // Cyrillic capitals
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P",
        "С": "C", "Т": "T", "Х": "X", "У": "Y", "І": "I", "Ј": "J", "Ѕ": "S",
        // Cyrillic small
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x", "к": "k",
        "і": "i", "ј": "j", "ѕ": "s", "һ": "h",
        // Greek capitals
        "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M",
        "Ν": "N", "Ο": "O", "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X",
        // Greek small
        "ο": "o", "ν": "v",
    ]
}
