import SwiftUI

/// Everything below the inputs: the payment, what the total is made of,
/// the rates, the schedule link and the comparison.
struct ResultSections: View {
    let result: LoanResult
    let store: LoanStore

    var body: some View {
        Section {
            headline
            breakdown
        }

        Section {
            figure("ריבית שנתית", "פריים ועוד מרווח", Fmt.percent(result.annualRate))
            figure(
                "עלות אשראי שנתית", "כולל עמלות וריבית דריבית",
                result.effectiveAnnualCost.map(Fmt.percent) ?? "לא זמין"
            )
            figure(
                "תשלום אחרון",
                result.repaymentType == .balloon ? "כולל החזר הקרן" : "בחודש \(result.months)",
                Fmt.money(result.finalPayment)
            )
            figure(
                "מספר תשלומים",
                result.graceMonths > 0 ? "מתוך \(result.months) חודשים" : "תשלום בכל חודש",
                "\(result.months - result.graceMonths)"
            )
            NavigationLink("לוח סילוקין") {
                ScheduleView(result: result)
            }
        }

        compare
    }

    // MARK: Headline

    private var paymentNote: String? {
        var notes: [String] = []
        switch result.repaymentType {
        case .spitzer: break
        case .balloon: notes.append("ריבית בלבד. הקרן משולמת בתשלום האחרון")
        case .grace:
            notes.append("החל מחודש \(result.graceMonths + 1), אחרי \(result.graceMonths) חודשי גרייס")
        }
        if result.isCpiLinked {
            notes.append("התשלום יתעדכן לפי המדד")
        }
        return notes.isEmpty ? nil : notes.joined(separator: ". ")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("תשלום חודשי")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MoneyText(value: result.monthlyPayment)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let paymentNote {
                Text(paymentNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Breakdown

    private struct Part: Identifiable {
        let label: String
        let value: Double
        let color: Color
        var id: String { label }
    }

    private var parts: [Part] {
        [
            Part(label: "קרן", value: result.principal, color: .accentColor),
            Part(label: "ריבית", value: result.totalInterest, color: .accentColor.opacity(0.55)),
            Part(label: "הפרשי הצמדה", value: result.totalLinkage, color: .accentColor.opacity(0.28)),
            Part(label: "עמלת פתיחת תיק", value: result.fee, color: Color(.systemGray2)),
        ].filter { $0.value > 0 }
    }

    private var breakdown: some View {
        let parts = parts
        let total = parts.reduce(0) { $0 + $1.value }

        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("סך הכול תשלמו")
                    .fontWeight(.semibold)
                Spacer()
                MoneyText(value: result.totalPaid)
                    .font(.title3.weight(.semibold))
            }

            // One bar split in proportion to each part of the total
            GeometryReader { geo in
                let gaps = 3 * CGFloat(max(parts.count - 1, 0))
                HStack(spacing: 3) {
                    ForEach(parts) { part in
                        Capsule()
                            .fill(part.color)
                            .frame(width: max(3, (geo.size.width - gaps) * part.value / total))
                    }
                }
            }
            .frame(height: 10)
            .clipped()
            .animation(.snappy, value: parts.map(\.value))
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                ForEach(parts) { part in
                    HStack {
                        Circle()
                            .fill(part.color)
                            .frame(width: 10, height: 10)
                        Text(part.label)
                        Spacer()
                        MoneyText(value: part.value)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func figure(_ label: String, _ caption: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: value)
        } label: {
            Text(label)
            Text(caption)
        }
    }

    // MARK: Compare

    @ViewBuilder
    private var compare: some View {
        if let saved = store.saved {
            Section {
                delta("תשלום חודשי", result.monthlyPayment - saved.monthlyPayment)
                delta("סך הכול", result.totalPaid - saved.totalPaid)
                Button("שמירת הנוכחי במקומו") {
                    store.saved = SavedScenario(result)
                }
                Button("הסרת התרחיש השמור", role: .destructive) {
                    withAnimation(.snappy) { store.saved = nil }
                }
            } header: {
                Text("לעומת התרחיש השמור")
            } footer: {
                Text("\(Fmt.money(saved.principal, cents: false)), \(saved.months) חודשים, \(saved.repaymentType.label), ריבית \(Fmt.percent(saved.annualRate))")
            }
        } else {
            Section {
                Button("שמירה להשוואה") {
                    withAnimation(.snappy) { store.saved = SavedScenario(result) }
                }
            } footer: {
                Text("שמרו את ההלוואה הזו, שנו את הנתונים, וראו כמה ההבדל.")
            }
        }
    }

    private func delta(_ label: String, _ diff: Double) -> some View {
        let same = abs(diff) < 0.005
        return LabeledContent(label) {
            if same {
                Text("ללא שינוי")
            } else {
                MoneyText(value: diff, signed: true)
                    .fontWeight(.semibold)
                    // Cheaper is good news, more expensive is not
                    .foregroundStyle(diff < 0 ? Color.accentColor : Color.red)
            }
        }
    }
}
