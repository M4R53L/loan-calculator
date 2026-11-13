import Foundation
import PDFKit
import Testing
@testable import LoanCalculator

private func close(_ a: Double?, _ b: Double, _ tolerance: Double) -> Bool {
    guard let a else { return false }
    return abs(a - b) <= tolerance
}

struct CalculatorTests {
    @Test func goldenCases() {
        let a = LoanCalculator.calculate(principal: 76500, prime: 4.5, margin: 4.6, months: 60)
        #expect(close(a.monthlyPayment, 1591.73, 0.5))
        #expect(close(a.totalInterest, 19003.77, 50))

        let b = LoanCalculator.calculate(principal: 20000, prime: 4, margin: 3, months: 48)
        #expect(close(b.monthlyPayment, 478.92, 0.5))
        #expect(close(b.totalInterest, 2988.39, 50))

        let c = LoanCalculator.calculate(principal: 50000, prime: 1.6, margin: 5.1, months: 60)
        #expect(close(c.monthlyPayment, 983.00, 0.5))
        #expect(close(c.totalInterest, 8979.89, 50))
    }

    @Test func zeroInterest() {
        let r = LoanCalculator.calculate(principal: 20000, prime: 0, margin: 0, months: 48)
        #expect(close(r.monthlyPayment, 416.67, 0.01))
        #expect(close(r.totalInterest, 0, 0.01))
    }

    @Test func scheduleClears() {
        let r = LoanCalculator.calculate(principal: 10000, prime: 2, margin: 3, months: 12)
        #expect(r.schedule.count == 12)
        #expect(r.schedule.first?.month == 1)
        #expect(close(r.schedule.last?.remainingBalance, 0, 1))
    }

    /// Published by Mimun Yashir: total cost 9.66%, total payments ₪36,817
    @Test func mimunYashirExample() {
        let r = LoanCalculator.calculate(
            principal: 30000, prime: 4.75, margin: 3.75, months: 55, fee: 490)
        #expect(close(r.monthlyPayment, 660.51, 0.05))
        #expect(close(r.totalPaid, 36817, 2))
        #expect(close(r.effectiveAnnualCost, 9.66, 0.02))
    }

    @Test func noFeeEffectiveCostIsCompoundedRate() {
        let r = LoanCalculator.calculate(principal: 50000, prime: 6, margin: 0, months: 36)
        // (1 + 0.06/12)^12 - 1 = 6.1678%
        #expect(close(r.effectiveAnnualCost, 6.1678, 0.001))
    }

    @Test func balloon() {
        let r = LoanCalculator.calculate(
            principal: 60000, prime: 4, margin: 2, months: 24, repaymentType: .balloon)
        #expect(close(r.monthlyPayment, 300, 0.01))
        #expect(close(r.finalPayment, 60300, 0.01))
        #expect(close(r.totalInterest, 300 * 24, 0.01))
        #expect(close(r.schedule.last?.remainingBalance, 0, 0.01))
    }

    /// Mimun Yashir's grace example: ₪65,000 over 24 months, about ₪3,430
    @Test func grace() {
        let r = LoanCalculator.calculate(
            principal: 65000, prime: 4.75, margin: 4.25, months: 24, repaymentType: .grace)
        #expect(r.schedule.prefix(3).allSatisfy { $0.payment == 0 })
        #expect(close(r.schedule[2].remainingBalance, 65000 * 1.0075 * 1.0075 * 1.0075, 0.01))
        #expect(r.graceMonths == 3)
        #expect(close(r.monthlyPayment, 3433, 2))
        #expect(close(r.schedule.last?.remainingBalance, 0, 0.01))

        let regular = LoanCalculator.calculate(
            principal: 65000, prime: 4.75, margin: 4.25, months: 24)
        #expect(r.totalInterest > regular.totalInterest)
    }

    @Test func cpiLinked() {
        let linked = LoanCalculator.calculate(
            principal: 30000, prime: 4.75, margin: 3.75, months: 55, annualInflationPercent: 3)
        let unlinked = LoanCalculator.calculate(
            principal: 30000, prime: 4.75, margin: 3.75, months: 55)

        #expect(linked.schedule.last!.payment > linked.schedule.first!.payment)
        #expect(close(linked.schedule.last?.remainingBalance, 0, 0.01))
        #expect(linked.totalLinkage > 0)
        #expect(linked.totalPaid > unlinked.totalPaid)
        #expect(close(linked.totalInstallments,
                      30000 + linked.totalInterest + linked.totalLinkage, 0.01))
    }
}

struct BorrowTests {
    /// Sizing a loan by its own payment gives the loan back
    @Test(arguments: RepaymentType.allCases)
    func roundTrip(track: RepaymentType) throws {
        let loan = LoanCalculator.calculate(
            principal: 80000, prime: 4.75, margin: 6.75, months: 48,
            repaymentType: track, annualInflationPercent: 2)
        let principal = try #require(LoanCalculator.principal(
            forMonthlyPayment: loan.monthlyPayment, prime: 4.75, margin: 6.75, months: 48,
            repaymentType: track, annualInflationPercent: 2))
        #expect(close(principal, 80000, 1))
    }

    @Test func noPaymentToSizeBy() {
        #expect(LoanCalculator.principal(
            forMonthlyPayment: 1000, prime: 0, margin: 0, months: 24,
            repaymentType: .balloon) == nil)
        #expect(LoanCalculator.principal(
            forMonthlyPayment: 0, prime: 4, margin: 2, months: 24) == nil)
    }
}

struct ReportTests {
    @Test func pdfHasEveryMonth() throws {
        let loan = LoanCalculator.calculate(
            principal: 50000, prime: 4.75, margin: 6.75, months: 100, fee: 490,
            annualInflationPercent: 3)
        let data = LoanReport(result: loan).pdfData()
        let pdf = try #require(PDFDocument(data: data))
        // Pass TEST_RUNNER_SHOTS=<folder> to keep a copy to look at
        if let dir = ProcessInfo.processInfo.environment["SHOTS"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("report.pdf"))
        }
        #expect(pdf.pageCount >= 2)
        let text = pdf.string ?? ""
        #expect(text.contains("100"))
        #expect(text.contains("50,000.00"))
    }
}

@MainActor
struct StoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsGiveAResult() {
        let store = LoanStore(defaults: freshDefaults())
        #expect(store.marginText == "6.75")
        #expect(close(store.result?.monthlyPayment, 1099.63, 0.01))
    }

    @Test func validation() {
        let store = LoanStore(defaults: freshDefaults())
        store.principalText = "1,000"
        #expect(store.principalError != nil)
        #expect(store.result == nil)

        store.principalText = "50,000"
        store.monthsText = "120"
        #expect(store.monthsError != nil)

        store.monthsText = "60"
        store.feeText = "60,000"
        #expect(store.feeError != nil)

        store.feeText = "490"
        store.marginText = "48"
        #expect(store.marginError != nil)

        store.reset()
        #expect(store.result != nil)
    }

    @Test func remembersInputsAndSavedScenario() {
        let defaults = freshDefaults()
        let first = LoanStore(defaults: defaults)
        first.principalText = "120,000"
        first.track = .balloon
        first.cpiLinked = true
        first.saved = SavedScenario(first.result!)

        let second = LoanStore(defaults: defaults)
        #expect(second.principalText == "120,000")
        #expect(second.track == .balloon)
        #expect(second.cpiLinked)
        #expect(second.saved == first.saved)
    }

    @Test func borrowMode() {
        let store = LoanStore(defaults: freshDefaults())
        store.mode = .borrow
        store.targetText = "1,100"
        // 1,099.63 a month is the default 50,000 loan
        #expect(close(store.result?.principal, 50016, 2))
        #expect(close(store.result?.monthlyPayment, 1100, 0.05))

        store.targetText = "100"
        #expect(store.targetError != nil)
        #expect(store.result == nil)

        store.targetText = "50,000"
        #expect(store.targetError != nil)

        // A broken term is reported on the term, not on the payment
        store.targetText = "1,100"
        store.monthsText = "5"
        #expect(store.targetError == nil)
        #expect(store.monthsError != nil)
    }

    @Test func sanitizers() {
        #expect(Fmt.ungrouped("50,000") == "50000")
        #expect(Fmt.sanitizeWhole("12a3456") == "123,456")
        #expect(Fmt.sanitizeWhole("") == "")
        #expect(Fmt.sanitizeDecimal("4.7.5") == "4.75")
        #expect(Fmt.sanitizeDecimal("-2.5", allowNegative: true) == "-2.5")
        #expect(Fmt.sanitizeDecimal("-2.5") == "2.5")
        #expect(Fmt.parse("50,000") == 50000)
    }
}
