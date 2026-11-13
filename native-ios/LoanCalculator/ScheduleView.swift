import SwiftUI

/// The amortization schedule, one row per month.
struct ScheduleView: View {
    let result: LoanResult

    var body: some View {
        List {
            Section {
                ForEach(result.schedule) { row in
                    ScheduleRow(
                        row: row,
                        isGrace: row.month <= result.graceMonths,
                        showLinkage: result.isCpiLinked
                    )
                }
            } header: {
                Text("הפס בכל שורה מראה כמה מהתשלום הוא קרן וכמה ריבית.")
                    .textCase(nil)
            } footer: {
                Text("סך הכול \(Fmt.money(result.totalInstallments)) ב־\(result.months) חודשים, לא כולל עמלת פתיחת תיק.")
            }
        }
        .navigationTitle("לוח סילוקין")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: LoanReport(result: result),
                    preview: SharePreview("סיכום הלוואה")
                )
            }
        }
    }
}

private struct ScheduleRow: View {
    let row: AmortizationRow
    let isGrace: Bool
    let showLinkage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("חודש \(row.month)")
                    .fontWeight(.medium)
                if isGrace {
                    Text("גרייס, בלי תשלום")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.money(row.payment))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            // How this payment splits between principal and interest
            if row.payment > 0 {
                GeometryReader { geo in
                    let principalWidth = (geo.size.width - 2) * row.principalPortion / row.payment
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.ink)
                            .frame(width: max(0, principalWidth))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cost)
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }

            HStack(alignment: .top, spacing: 12) {
                detail("קרן", row.principalPortion, .ink)
                detail("ריבית", row.interestPortion, .cost)
                if showLinkage {
                    detail("הצמדה", row.linkage, .linkage)
                }
                detail("יתרה", row.remainingBalance, nil)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: Double, _ color: Color?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if let color {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
                Text(label)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(Fmt.money(value, cents: false))
                .font(.caption)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
