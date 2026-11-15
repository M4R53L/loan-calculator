import SwiftUI

/// Three equal columns, shared by the cost's parts and the rates under
/// them, so the two rows line up. Each column gets its width up front,
/// which keeps the text at full size whenever it fits.
private let threeColumns = Array(
    repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading), count: 3)

/// What the loan costs: the total and what it is made of, then the rates.
/// Shown in the app and in the shared image.
struct CostSummary: View {
    let result: LoanResult
    /// No answer for the inputs as they are: --- in place of every value,
    /// and a grey bar. `result` is then the last answer, kept only for the
    /// layout, which stays exactly as it was.
    var placeholder = false

    /// --- while there is no answer
    private func shown(_ value: Figure.Value) -> Figure.Value {
        placeholder ? .text("---") : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cost
            Divider()
            figures
        }
    }

    private struct Part: Identifiable {
        let label: String
        let value: Double
        let color: Color
        var id: String { label }
    }

    private var parts: [Part] {
        [
            Part(label: "קרן", value: result.principal, color: .ink),
            Part(label: "ריבית", value: result.totalInterest, color: .cost),
            Part(label: "הצמדה", value: result.totalLinkage, color: .linkage),
        ].filter { $0.value > 0 }
    }

    private var cost: some View {
        let parts = parts
        let total = parts.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("סך הכול תשלמו")
                Spacer()
                Text(placeholder ? "---" : Fmt.money(result.totalPaid))
                    .monospacedDigit()
            }
            .fontWeight(.bold)
            .accessibilityElement(children: .combine)

            // One bar split in proportion to each part of the total
            GeometryReader { geo in
                let gaps = 3 * CGFloat(max(parts.count - 1, 0))
                HStack(spacing: 3) {
                    ForEach(parts) { part in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(placeholder ? Color(.systemGray4) : part.color)
                            .frame(width: max(3, (geo.size.width - gaps) * part.value / total))
                    }
                }
            }
            .frame(height: 12)
            .clipped()
            .animation(.snappy, value: parts.map(\.value))
            .accessibilityHidden(true)

            // The parts on one row, each keyed to its colour in the bar
            LazyVGrid(columns: threeColumns, alignment: .leading) {
                ForEach(parts) { part in
                    Figure(label: part.label, value: shown(.money(part.value, cents: false)),
                           swatch: part.color)
                }
            }
        }
    }

    // Only the figures the inputs do not already show

    /// One row, under the parts. The grace months are not repeated here:
    /// the note under the headline gives them.
    private var figures: some View {
        LazyVGrid(columns: threeColumns, alignment: .leading) {
            Figure(label: "ריבית שנתית", value: shown(.percent(result.annualRate)))
            Figure(label: "עלות אשראי שנתית",
                   value: shown(result.effectiveAnnualCost.map { .percent($0) } ?? .text("לא זמין")))
            if abs(result.finalPayment - result.monthlyPayment) > 0.005 {
                Figure(
                    label: result.repaymentType == .balloon ? "תשלום אחרון, עם הקרן" : "תשלום אחרון",
                    value: shown(.money(result.finalPayment))
                )
            }
        }
    }
}

/// A small label over a value, optionally keyed to a colour.
///
/// The values change at once, without rolling: only the headline rolls.
/// Rolling every figure in the cost card cost more than the headline itself
/// while a slider was dragged, as each moving character is blended frame by
/// frame.
struct Figure: View {
    enum Value: Equatable {
        case text(String)
        case money(Double, cents: Bool = true)
        case percent(Double)

        /// As plain text, the way iOS writes it in Hebrew
        var plain: String {
            switch self {
            case .text(let text): text
            case .money(let value, let cents): Fmt.money(value, cents: cents)
            case .percent(let value): Fmt.percent(value)
            }
        }
    }

    let label: String
    let value: Value
    var swatch: Color? = nil

    init(label: String, value: Value, swatch: Color? = nil) {
        self.label = label
        self.value = value
        self.swatch = swatch
    }

    init(label: String, value: String) {
        self.init(label: label, value: .text(value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if let swatch {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(swatch)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value.plain)
                .fontWeight(.medium)
                .monospacedDigit()
                // Room for a large balloon's last payment, such as
                // ₪483,030.86, in a third of an iPhone 16's width
                .minimumScaleFactor(0.7)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

}
