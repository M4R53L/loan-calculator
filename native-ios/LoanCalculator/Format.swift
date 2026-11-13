import Foundation

enum Fmt {
    static let hebrew = Locale(identifier: "he_IL")
    private static let plain = Locale(identifier: "en_US")

    /// Shekel amount the way iOS writes it in Hebrew
    static func money(_ value: Double, cents: Bool = true) -> String {
        value.formatted(
            .currency(code: "ILS")
                .precision(.fractionLength(cents ? 2 : 0))
                .locale(hebrew)
        )
    }

    /// Shekel difference with an explicit plus or minus
    static func signedMoney(_ value: Double) -> String {
        value.formatted(
            .currency(code: "ILS")
                .precision(.fractionLength(2))
                .sign(strategy: .always())
                .locale(hebrew)
        )
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    /// "1,099.63", digits only, for figures that set their own ₪
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(plain))
    }

    /// "50,000", for the amount fields
    static func grouped(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(plain))
    }

    /// The digits of a grouped amount, as shown while its field is being edited
    static func ungrouped(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: "")
    }

    /// Parses user input that may contain thousands separators.
    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }

    /// Digits only, regrouped with thousands separators.
    static func sanitizeWhole(_ text: String) -> String {
        let digits = text.filter(\.isASCIIDigit).prefix(9)
        guard let value = Double(digits) else { return "" }
        return grouped(value)
    }

    /// Digits with at most one decimal point, and optionally a leading minus.
    static func sanitizeDecimal(_ text: String, allowNegative: Bool = false) -> String {
        var out = ""
        var seenDot = false
        for ch in text {
            if ch.isASCIIDigit {
                out.append(ch)
            } else if (ch == "." || ch == ",") && !seenDot {
                seenDot = true
                out.append(".")
            } else if ch == "-" && allowNegative && out.isEmpty {
                out.append(ch)
            }
        }
        return out
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
