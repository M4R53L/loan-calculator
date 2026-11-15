import SwiftUI

extension Color {
    /// What was borrowed. Also the app's tint.
    static let ink = Color.accentColor
    /// What borrowing costs: interest.
    static let cost = Color("Cost")
    static let linkage = Color("Linkage")
    /// Interest colour dark enough to read as text
    static let costText = Color("CostText")
    /// Page background
    static let canvas = Color("Canvas")
    /// Background of the grouped rows
    static let card = Color("Card")
}

/// The answer: the monthly payment, or the amount that can be borrowed.
struct LoanHero: View {
    let result: LoanResult
    let mode: CalcMode
    /// Point size of the shekels. The calculator makes it as large as its
    /// space allows; see `figureSize(fitting:result:mode:)`.
    var figureSize: CGFloat = 68
    /// No answer for the inputs as they are: --- in place of the number.
    /// `result` is then the last answer, kept only to hold the layout.
    var placeholder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.label(mode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HeadlineFigure(value: Self.value(result, mode), showCents: mode == .payment,
                           size: figureSize, placeholder: placeholder)
            if let note = Self.note(result, mode) {
                // Hidden, not removed, so the headline keeps its height
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .opacity(placeholder ? 0 : 1)
                    .accessibilityHidden(placeholder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hero")
    }

    private static func label(_ mode: CalcMode) -> String {
        mode == .borrow ? "תוכלו ללוות" : "תשלום חודשי"
    }

    private static func value(_ result: LoanResult, _ mode: CalcMode) -> Double {
        mode == .borrow ? result.principal : result.monthlyPayment
    }

    /// Only where the headline number needs explaining
    private static func note(_ result: LoanResult, _ mode: CalcMode) -> String? {
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

    /// The largest figure that fits `space`, limited by whichever runs out
    /// first, the width or the height. Measured with the real fonts.
    ///
    /// The width is measured on 8s with as many digits as the answer has,
    /// so the size holds still as the number changes and moves only when a
    /// digit is added or dropped.
    static func figureSize(fitting space: CGSize, result: LoanResult, mode: CalcMode) -> CGFloat {
        let reference: CGFloat = 100
        let text = Fmt.decimal(value(result, mode))
            .map { $0.isNumber ? "8" : $0 }.reduce(into: "") { $0.append($1) }
        let dot = text.firstIndex(of: ".") ?? text.endIndex
        let showCents = mode == .payment

        func width(_ string: some StringProtocol, _ size: CGFloat, _ weight: UIFont.Weight,
                   condensed: Bool = true) -> CGFloat {
            let font = condensed
                ? UIFont.systemFont(ofSize: size, weight: weight, width: .condensed)
                : UIFont.systemFont(ofSize: size, weight: weight)
            return (String(string) as NSString).size(withAttributes: [.font: font]).width
        }
        let figureWidth = width(text[..<dot], reference, .bold)
            + (showCents ? width(text[dot...], reference * HeadlineFigure.agorot, .semibold) : 0)
            + width("₪", reference * HeadlineFigure.sign, .medium, condensed: false)
        // A little to spare, for digits wider than an 8
        let byWidth = (space.width - HeadlineFigure.spacing) / figureWidth * reference * 0.96

        let line = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
        let lines = 1 + (note(result, mode)?.split(separator: "\n").count ?? 0)
        let figureLine = UIFont.systemFont(ofSize: reference, weight: .bold, width: .condensed)
            .lineHeight / reference
        let byHeight = (space.height - CGFloat(lines) * line) / figureLine

        return min(max(min(byWidth, byHeight), 40), 150)
    }
}

/// The headline amount, set large in the system font's condensed width.
/// Shekels carry the weight, agorot and the sign step back.
private struct HeadlineFigure: View {
    let value: Double
    let showCents: Bool
    let size: CGFloat
    var placeholder = false

    /// Agorot and the sign, as a share of the shekels' size
    static let agorot = 30.0 / 68
    static let sign = 26.0 / 68
    static let spacing = 8.0

    /// Which way the digits roll: shekels and agorot go the same way, the
    /// way the whole amount moved
    @State private var direction = RollDirection()
    /// The amount on screen. It follows `value` at most every 0.1 s, so a
    /// fast slider shows a steady run of clean rolls instead of a pile of
    /// half-finished ones, and always lands on the final amount.
    @State private var shown: Double?
    @State private var lastShown = Date.distantPast
    @State private var pending: Task<Void, Never>?

    private static let pace = 0.1

    var body: some View {
        let value = shown ?? self.value
        let text = Fmt.decimal(value)
        let dot = text.firstIndex(of: ".") ?? text.endIndex
        let rising = direction.update(value)

        // Digits always read left to right, with ₪ where Hebrew puts it
        HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
            Text("₪")
                .font(.system(size: size * Self.sign, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if placeholder {
                    Text("---")
                        .font(.system(size: size, weight: .bold).width(.condensed))
                        .foregroundStyle(.secondary)
                } else {
                    // Each digit rolls on its own; see RollingDigits
                    RollingDigits(text: String(text[..<dot]), rising: rising)
                        .font(.system(size: size, weight: .bold).width(.condensed))
                    if showCents {
                        RollingDigits(text: String(text[dot...]), rising: rising)
                            .font(.system(size: size * Self.agorot, weight: .semibold).width(.condensed))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .environment(\.layoutDirection, .leftToRight)
        .animation(.snappy(duration: 0.25), value: value)
        .animation(.snappy(duration: 0.25), value: size)
        .onChange(of: self.value) { _, new in follow(new) }
        .onDisappear { pending?.cancel() }
        .accessibilityElement()
        .accessibilityLabel(placeholder ? "אין חישוב" : Fmt.money(value, cents: showCents))
    }

    /// Shows a new amount now, or, if one was shown less than `pace` ago,
    /// as soon as that time is up. A newer amount replaces a waiting one.
    private func follow(_ new: Double) {
        pending?.cancel()
        let wait = Self.pace - Date.now.timeIntervalSince(lastShown)
        guard wait > 0 else { return show(new) }
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            show(new)
        }
    }

    private func show(_ new: Double) {
        shown = new
        lastShown = .now
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
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noResult")
    }
}
