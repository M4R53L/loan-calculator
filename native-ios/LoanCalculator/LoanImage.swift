import SwiftUI
import UniformTypeIdentifiers

/// The loan as a PNG to share. It is drawn only when the share sheet asks
/// for it, not on every change to the inputs.
struct LoanImage: Transferable {
    let result: LoanResult
    let mode: CalcMode

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await image.pngData()
        }
        .suggestedFileName("סיכום הלוואה.png")
    }

    @MainActor
    func pngData() throws -> Data {
        let renderer = ImageRenderer(content: LoanShareCard(result: result, mode: mode))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}

/// The shared image: the app's headline figure and cards on its canvas.
/// The renderer does not inherit the app's environment, so it is set here,
/// and fixed to light mode and the default text size so every image looks
/// the same.
struct LoanShareCard: View {
    let result: LoanResult
    let mode: CalcMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("מחשבון הלוואה")
                    .font(.headline)
                Spacer()
                Text(Date.now, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // As wide as the card allows, the way the app shows it
            LoanHero(result: result, mode: mode,
                     figureSize: LoanHero.figureSize(
                        fitting: CGSize(width: 342, height: CGFloat.infinity), result: result, mode: mode))
                .padding(.horizontal, 4)

            card { details }
            card { CostSummary(result: result) }

            Text(Disclaimer.short)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(20)
        .frame(width: 390)
        .background(Color.canvas)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Fmt.hebrew)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    /// The loan the figures are for
    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Figure(label: "סכום ההלוואה", value: Fmt.money(result.principal, cents: false))
                Figure(label: "תקופה", value: "\(result.months) חודשים")
            }
            GridRow {
                Figure(label: "מסלול החזר", value: result.repaymentType.label)
                if result.isCpiLinked {
                    Figure(label: "צמוד למדד",
                           value: "\(Fmt.percent(result.annualInflationPercent)) בשנה")
                } else {
                    Figure(label: "צמוד למדד", value: "לא")
                }
            }
        }
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    LoanShareCard(
        result: LoanCalculator.calculate(principal: 50000, prime: 4.75, margin: 6.75, months: 60,
                                         annualInflationPercent: 3),
        mode: .payment
    )
}
