import CoreTransferable
import UIKit
import UniformTypeIdentifiers

/// The loan as a PDF to share: a summary, then the full schedule.
struct LoanReport: Transferable {
    let result: LoanResult

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { report in
            report.pdfData()
        }
        .suggestedFileName("סיכום הלוואה.pdf")
    }

    func pdfData() -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let margin: CGFloat = 40
        let width = page.width - margin * 2
        let ink = UIColor.black
        let muted = UIColor(white: 0.4, alpha: 1)

        func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect,
                  align: NSTextAlignment = .right) {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.baseWritingDirection = .rightToLeft
            style.lineBreakMode = .byTruncatingTail
            NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: style,
            ]).draw(in: rect)
        }

        var summary: [(String, String)] = [
            ("סכום ההלוואה", Fmt.money(result.principal)),
            ("תקופה", "\(result.months) חודשים"),
            ("מסלול החזר", result.repaymentType.label),
            ("ריבית שנתית", Fmt.percent(result.annualRate)),
            ("עלות אשראי שנתית", result.effectiveAnnualCost.map(Fmt.percent) ?? "לא זמין"),
            ("תשלום חודשי", Fmt.money(result.monthlyPayment)),
            ("סך הריבית", Fmt.money(result.totalInterest)),
        ]
        if result.isCpiLinked {
            summary.append(("הפרשי הצמדה, לפי מדד משוער של \(Fmt.percent(result.annualInflationPercent))",
                            Fmt.money(result.totalLinkage)))
        }
        if result.fee > 0 {
            summary.append(("עמלת פתיחת תיק", Fmt.money(result.fee)))
        }
        summary.append(("סך הכול תשלמו", Fmt.money(result.totalPaid)))

        // Columns run right to left, as the table is read
        var columns: [(title: String, width: CGFloat, value: (AmortizationRow) -> String)] = [
            ("חודש", 50, { "\($0.month)" }),
            ("תשלום", 0, { Fmt.money($0.payment) }),
            ("קרן", 0, { Fmt.money($0.principalPortion) }),
            ("ריבית", 0, { Fmt.money($0.interestPortion) }),
        ]
        if result.isCpiLinked {
            columns.append(("הצמדה", 0, { Fmt.money($0.linkage) }))
        }
        columns.append(("יתרה", 0, { Fmt.money($0.remainingBalance) }))
        let flexible = (width - 50) / CGFloat(columns.count - 1)
        for i in columns.indices where columns[i].width == 0 {
            columns[i].width = flexible
        }

        let body = UIFont.systemFont(ofSize: 10)
        let bold = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let rowHeight: CGFloat = 17

        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            var y = margin

            func tableRow(_ cells: [String], font: UIFont, color: UIColor) {
                var right = page.width - margin
                for (cell, column) in zip(cells, columns) {
                    draw(cell, font: font, color: color,
                         in: CGRect(x: right - column.width, y: y, width: column.width - 6, height: rowHeight))
                    right -= column.width
                }
                y += rowHeight
            }

            func tableHeader() {
                tableRow(columns.map(\.title), font: bold, color: muted)
                context.cgContext.setStrokeColor(UIColor(white: 0.75, alpha: 1).cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y))
                context.cgContext.strokePath()
                y += 4
            }

            context.beginPage()
            draw("סיכום הלוואה", font: .systemFont(ofSize: 22, weight: .bold), color: ink,
                 in: CGRect(x: margin, y: y, width: width, height: 30))
            y += 32
            let date = Date.now.formatted(.dateTime.day().month(.wide).year().locale(Fmt.hebrew))
            draw("הופק ב־\(date)", font: body, color: muted,
                 in: CGRect(x: margin, y: y, width: width, height: 14))
            y += 28

            for (index, (label, value)) in summary.enumerated() {
                let last = index == summary.count - 1
                let font = UIFont.systemFont(ofSize: 12, weight: last ? .bold : .regular)
                draw(label, font: font, color: ink,
                     in: CGRect(x: margin + 150, y: y, width: width - 150, height: 18))
                draw(value, font: font, color: ink,
                     in: CGRect(x: margin, y: y, width: 150, height: 18), align: .left)
                y += 20
            }
            y += 20

            draw("לוח סילוקין", font: .systemFont(ofSize: 15, weight: .bold), color: ink,
                 in: CGRect(x: margin, y: y, width: width, height: 20))
            y += 26
            tableHeader()

            for row in result.schedule {
                if y + rowHeight > page.height - margin {
                    context.beginPage()
                    y = margin
                    tableHeader()
                }
                tableRow(columns.map { $0.value(row) }, font: body, color: ink)
            }
        }
    }
}
