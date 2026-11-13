import SwiftUI

/// Below the inputs: what the loan costs, the rates, the schedule link
/// and the comparison.
struct ResultSections: View {
    let result: LoanResult
    let store: LoanStore

    var body: some View {
        costSection

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
            ShareLink(
                "שיתוף הסיכום ולוח הסילוקין",
                item: LoanReport(result: result),
                preview: SharePreview("סיכום הלוואה")
            )
        }

        compare
    }

    // MARK: Cost. Reads as a sum: the parts, then the total.

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
            Part(label: "הפרשי הצמדה", value: result.totalLinkage, color: .linkage),
            Part(label: "עמלת פתיחת תיק", value: result.fee, color: Color(.systemGray2)),
        ].filter { $0.value > 0 }
    }

    private var costSection: some View {
        let parts = parts
        let total = parts.reduce(0) { $0 + $1.value }
        let extra = result.totalPaid - result.principal

        return Section {
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
            .frame(height: 14)
            .clipped()
            .padding(.vertical, 6)
            .animation(.snappy, value: parts.map(\.value))
            .accessibilityHidden(true)

            ForEach(parts) { part in
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(part.color)
                        .frame(width: 12, height: 12)
                    Text(part.label)
                    Spacer()
                    MoneyText(value: part.value)
                }
                .accessibilityElement(children: .combine)
            }

            HStack {
                Text("סך הכול תשלמו")
                Spacer()
                MoneyText(value: result.totalPaid)
            }
            .fontWeight(.bold)
            .accessibilityElement(children: .combine)
        } header: {
            Text("כמה זה עולה")
        } footer: {
            Text("תחזירו \(Fmt.money(extra, cents: false)) מעבר לסכום שקיבלתם.")
        }
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
                    // Paying more takes the cost colour, paying less the ink
                    .foregroundStyle(diff < 0 ? Color.ink : Color.cost)
            }
        }
    }
}
