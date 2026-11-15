import SwiftUI

/// Below the inputs: one card with what the loan costs, then one row of
/// actions.
struct ResultSections: View {
    let result: LoanResult
    let store: LoanStore

    private static let twoColumns = [
        GridItem(.flexible(), spacing: 16, alignment: .topLeading),
        GridItem(.flexible(), alignment: .topLeading),
    ]

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                cost
                Divider()
                figures
                if let saved = store.saved {
                    Divider()
                    comparison(with: saved)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.card)

        Section {
            actions
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: Cost: the total, and what it is made of

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
            Part(label: "עמלה", value: result.fee, color: Color(.systemGray2)),
        ].filter { $0.value > 0 }
    }

    private var cost: some View {
        let parts = parts
        let total = parts.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("סך הכול תשלמו")
                Spacer()
                MoneyText(value: result.totalPaid)
            }
            .fontWeight(.bold)
            .accessibilityElement(children: .combine)

            // One bar split in proportion to each part of the total
            GeometryReader { geo in
                let gaps = 3 * CGFloat(max(parts.count - 1, 0))
                HStack(spacing: 3) {
                    ForEach(parts) { part in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(part.color)
                            .frame(width: max(3, (geo.size.width - gaps) * part.value / total))
                    }
                }
            }
            .frame(height: 12)
            .clipped()
            .animation(.snappy, value: parts.map(\.value))
            .accessibilityHidden(true)

            LazyVGrid(columns: Self.twoColumns, alignment: .leading, spacing: 6) {
                ForEach(parts) { part in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(part.color)
                            .frame(width: 10, height: 10)
                        Text(part.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        MoneyText(value: part.value, cents: false)
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Figures. Only the ones the inputs do not already show.

    private var figures: some View {
        LazyVGrid(columns: Self.twoColumns, alignment: .leading, spacing: 10) {
            figure("ריבית שנתית", Fmt.percent(result.annualRate))
            figure("עלות אשראי שנתית", result.effectiveAnnualCost.map(Fmt.percent) ?? "לא זמין")
            if abs(result.finalPayment - result.monthlyPayment) > 0.005 {
                figure(
                    result.repaymentType == .balloon ? "תשלום אחרון, עם הקרן" : "תשלום אחרון",
                    Fmt.money(result.finalPayment)
                )
            }
            if result.graceMonths > 0 {
                figure("מספר תשלומים",
                       "\(result.months - result.graceMonths) מתוך \(result.months) חודשים")
            }
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: value)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Comparison with the saved loan

    private func comparison(with saved: SavedScenario) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("לעומת \(Fmt.money(saved.principal, cents: false)), \(saved.months) חודשים, \(saved.repaymentType.label), ריבית \(Fmt.percent(saved.annualRate))")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Self.twoColumns, alignment: .leading, spacing: 10) {
                delta("תשלום חודשי", result.monthlyPayment - saved.monthlyPayment)
                delta("סך הכול", result.totalPaid - saved.totalPaid)
            }
        }
    }

    private func delta(_ label: String, _ diff: Double) -> some View {
        let same = abs(diff) < 0.005
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if same {
                Text("ללא שינוי")
                    .fontWeight(.medium)
            } else {
                MoneyText(value: diff, signed: true)
                    .fontWeight(.semibold)
                    // Paying more takes the cost colour, paying less the ink
                    .foregroundStyle(diff < 0 ? Color.ink : Color.costText)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 8) {
            if store.saved == nil {
                Button {
                    withAnimation(.snappy) { store.saved = SavedScenario(result) }
                } label: {
                    actionLabel("שמירה להשוואה")
                }
            } else {
                Menu {
                    Button("שמירת הנוכחי במקומו") {
                        store.saved = SavedScenario(result)
                    }
                    Button("הסרת התרחיש השמור", role: .destructive) {
                        withAnimation(.snappy) { store.saved = nil }
                    }
                } label: {
                    actionLabel("השוואה")
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 30)
    }
}
