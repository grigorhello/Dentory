import Foundation

/// A quantity in a text field and back (MS-117): shown in the clinic's locale without digit grouping, read
/// with the locale's grouping and decimal separators and native digits, and refused when it is anything
/// else, so "1,000" never becomes 1 and "abc" never becomes 0.
nonisolated enum QuantityText {
    /// "1000" or "20,5" in the clinic's locale.
    static func plain(_ value: Decimal, locale: Locale) -> String {
        value.formatted(Decimal.FormatStyle(locale: locale).grouping(.never))
    }

    /// "20", "20.5", ".5", "1,000.5" in en_US, "1 000,5" in fr_CA or "١٠٠٠" in ar_SA; nil for anything else.
    static func parse(_ text: String, locale: Locale) -> Decimal? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        cleaned = cleaned.map { character -> String in
            if let digit = character.wholeNumberValue, (0...9).contains(digit) { return String(digit) }
            return String(character)
        }.joined()
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparators = Set([locale.groupingSeparator ?? ",", " ", "\u{00A0}", "\u{202F}"])
        for separator in groupingSeparators where separator != decimalSeparator {
            cleaned = cleaned.replacingOccurrences(of: separator, with: "")
        }
        cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
        let digitsAndPoint = cleaned.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") }
        guard digitsAndPoint, cleaned.contains(where: \.isNumber), cleaned.filter({ $0 == "." }).count <= 1 else {
            return nil
        }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// A whole number of 1 or more read the same way ("50", "٥٠"); nil for "2.5", "0" or anything else.
    static func count(_ text: String, locale: Locale) -> Int? {
        guard let value = parse(text, locale: locale), value >= 1 else { return nil }
        let whole = NSDecimalNumber(decimal: value).intValue
        return Decimal(whole) == value ? whole : nil
    }
}
