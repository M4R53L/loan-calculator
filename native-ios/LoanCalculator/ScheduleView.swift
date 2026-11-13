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
            } footer: {
                Text("סך הכול \(Fmt.money(result.totalInstallments)) ב־\(result.months) חודשים, לא כולל עמלת פתיחת תיק.")
            }
        }
        .navigationTitle("לוח סילוקין")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScheduleRow: View {
    let row: AmortizationRow
    let isGrace: Bool
    let showLinkage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("חודש \(row.month)")
                    .fontWeight(.medium)
                if isGrace {
                    Text("גרייס")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Text(Fmt.money(row.payment))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    detail("ריבית", row.interestPortion)
                    detail("קרן", row.principalPortion)
                    if showLinkage {
                        detail("הצמדה", row.linkage)
                    }
                    detail("יתרה", row.remainingBalance)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Fmt.money(value, cents: false))
                .font(.caption)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
