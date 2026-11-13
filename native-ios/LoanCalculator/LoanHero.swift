import SwiftUI

extension Color {
    /// What was borrowed. Also the app's tint.
    static let ink = Color.accentColor
    /// What borrowing costs: interest.
    static let cost = Color("Cost")
    static let linkage = Color("Linkage")
}

/// The answer: the monthly payment, or the amount that can be borrowed.
struct LoanHero: View {
    let result: LoanResult
    let mode: CalcMode

    /// Only where the headline number needs explaining
    private var note: String? {
        var lines: [String] = []
        if mode == .borrow {
            lines.append("בתשלום של \(Fmt.money(result.monthlyPayment)) בחודש")
        }
        switch result.repaymentType {
        case .spitzer: break
        case .balloon: lines.append("ריבית בלבד. הקרן משולמת בתשלום האחרון")
        case .grace:
            lines.append("החל מחודש \(result.graceMonths + 1), אחרי \(result.graceMonths) חודשי גרייס")
        }
        if result.isCpiLinked {
            lines.append("התשלום יתעדכן לפי המדד")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode == .borrow ? "תוכלו ללוות" : "תשלום חודשי")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HeadlineFigure(
                value: mode == .borrow ? result.principal : result.monthlyPayment,
                showCents: mode == .payment
            )
            if let note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hero")
    }
}

/// The headline amount, set large in the system font's condensed width.
/// Shekels carry the weight, agorot and the sign step back. Sizes follow
/// the phone's text-size setting.
private struct HeadlineFigure: View {
    let value: Double
    let showCents: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var shekelSize = 76.0
    @ScaledMetric(relativeTo: .largeTitle) private var agorotSize = 34.0
    @ScaledMetric(relativeTo: .largeTitle) private var signSize = 30.0

    var body: some View {
        let text = Fmt.decimal(value)
        let dot = text.firstIndex(of: ".") ?? text.endIndex

        // Digits always read left to right, with ₪ where Hebrew puts it
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("₪")
                .font(.system(size: signSize, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(text[..<dot])
                    .font(.system(size: shekelSize, weight: .bold).width(.condensed))
                if showCents {
                    Text(text[dot...])
                        .font(.system(size: agorotSize, weight: .semibold).width(.condensed))
                        .foregroundStyle(.secondary)
                }
            }
            .contentTransition(.numericText(value: value))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .environment(\.layoutDirection, .leftToRight)
        .animation(.snappy(duration: 0.3), value: value)
        .accessibilityElement()
        .accessibilityLabel(Fmt.money(value, cents: showCents))
    }
}

/// Shown in place of the answer while an input is missing or out of range.
struct NoResult: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("אין עדיין חישוב")
                .font(.title2.weight(.bold))
            Text("תקנו את השדות המסומנים באדום, והתוצאה תופיע כאן.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noResult")
    }
}
