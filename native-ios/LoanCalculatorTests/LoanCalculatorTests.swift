import Foundation
import UIKit
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

@MainActor
struct ImageTests {
    /// The shared image renders, at three times its 390-point width
    @Test(arguments: [CalcMode.payment, .borrow])
    func imageRenders(mode: CalcMode) throws {
        let loan = LoanCalculator.calculate(
            principal: 50000, prime: 4.75, margin: 6.75, months: 60,
            repaymentType: .grace, annualInflationPercent: 3)
        let data = try LoanImage(result: loan, mode: mode).pngData()
        let image = try #require(UIImage(data: data))
        // Pass TEST_RUNNER_SHOTS=<folder> to keep a copy to look at
        if let dir = ProcessInfo.processInfo.environment["SHOTS"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("share-\(mode).png"))
        }
        #expect(image.size.width * image.scale == 1170)
        #expect(image.size.height > image.size.width)
    }
}

struct RollingTests {
    /// Digits roll up when the number grows and down when it shrinks, and
    /// keep their last direction when it holds still or is not a number
    @Test func direction() {
        let roll = RollDirection()
        #expect(roll.update(1_099.63))
        #expect(roll.update(1_250))
        #expect(!roll.update(980.5))
        #expect(!roll.update(980.5))
        #expect(!roll.update(nil))
        #expect(roll.update(1_000))
    }

    @Test func readsTheNumber() {
        #expect(RollingDigits.number("1,099.63") == 1_099.63)
        #expect(RollingDigits.number(".45") == 0.45)
        #expect(RollingDigits.number("---") == nil)
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
        // Linked to the CPI at 3% a year to start with
        #expect(store.cpiLinked)
        #expect(close(store.result?.monthlyPayment, 1102.34, 0.01))
        store.cpiLinked = false
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
        store.marginText = "48"
        #expect(store.marginError != nil)

        store.reset()
        #expect(store.result != nil)
    }

    @Test func remembersInputs() {
        let defaults = freshDefaults()
        let first = LoanStore(defaults: defaults)
        first.principalText = "120,000"
        first.track = .balloon
        // Off is remembered too, though the switch starts on
        first.cpiLinked = false

        let second = LoanStore(defaults: defaults)
        #expect(second.principalText == "120,000")
        #expect(second.track == .balloon)
        #expect(!second.cpiLinked)
    }

    @Test func borrowMode() {
        let store = LoanStore(defaults: freshDefaults())
        store.cpiLinked = false
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

    @Test func publishedInflationFillsTheField() async {
        let defaults = freshDefaults()
        let store = LoanStore(defaults: defaults)
        let september = CPIReading(yearly: 1.6, year: 2026, month: 9)
        await store.refreshCPI { september }
        #expect(store.inflationText == "1.6")
        #expect(store.inflationIsFromCBS)

        // A newer month replaces it, but not within 12 hours of the last fetch
        let october = CPIReading(yearly: 2.1, year: 2026, month: 10)
        await store.refreshCPI(now: .now + 60) { october }
        #expect(store.inflationText == "1.6")
        await store.refreshCPI(now: .now + 13 * 60 * 60) { october }
        #expect(store.inflationText == "2.1")

        // A rate the user typed stays
        store.inflationText = "4"
        store.apply(CPIReading(yearly: -0.3, year: 2026, month: 11))
        #expect(store.inflationText == "4")
        #expect(!store.inflationIsFromCBS)

        // Reset goes back to the published rate, and it outlives a relaunch
        store.reset()
        #expect(store.inflationText == "-0.3")
        #expect(LoanStore(defaults: defaults).cpi?.month == 11)
    }

    @Test func noConnectionKeepsTheField() async {
        let store = LoanStore(defaults: freshDefaults())
        await store.refreshCPI { throw URLError(.notConnectedToInternet) }
        #expect(store.inflationText == LoanStore.Defaults.inflation)
        #expect(store.cpi == nil)
    }

    @Test func parsesTheCBSAnswer() throws {
        let json = """
        {"month":[{"code":120010,"name":"מדד המחירים לצרכן - כללי","date":[
          {"year":2026,"percent":0.7,"percentYear":1.5,"month":8},
          {"year":2026,"percent":-0.5,"percentYear":1.6,"month":9}]}],"quarter":null}
        """
        let reading = try CBS.parse(Data(json.utf8))
        #expect(reading == CPIReading(yearly: 1.6, year: 2026, month: 9))
        #expect(reading.period == "9/2026")
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
