import Foundation

/// How the loan principal is repaid
enum RepaymentType: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Fixed monthly payment of principal + interest (שפיצר)
    case spitzer
    /// Interest-only monthly payments, full principal at the end (בלון)
    case balloon
    /// No payments for the first months; the accrued interest is added to the
    /// balance and repaid with it over the remaining months (גרייס)
    case grace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spitzer: "שפיצר"
        case .balloon: "בלון"
        case .grace: "גרייס"
        }
    }
}

/// One month of the amortization schedule
struct AmortizationRow: Identifiable, Equatable, Sendable {
    let month: Int
    let payment: Double
    let interestPortion: Double
    let principalPortion: Double
    /// CPI linkage added to the balance this month
    let linkage: Double
    let remainingBalance: Double

    var id: Int { month }
}

struct LoanResult: Equatable, Sendable {
    let principal: Double
    let annualRate: Double
    let months: Int
    let repaymentType: RepaymentType
    let graceMonths: Int
    /// One-time file-opening fee (עמלת פתיחת תיק)
    let fee: Double
    /// Assumed yearly CPI change for a CPI-linked loan (0 = not linked)
    let annualInflationPercent: Double
    /// The regular monthly payment: the Spitzer payment, the payment after the
    /// grace period, or the interest-only payment of a balloon loan.
    /// For a CPI-linked loan this is the first payment; later ones grow.
    let monthlyPayment: Double
    /// For a balloon loan this includes the whole principal
    let finalPayment: Double
    let totalInstallments: Double
    let totalLinkage: Double
    let totalInterest: Double
    /// Everything the customer pays: all payments + fee
    let totalPaid: Double
    /// Effective annual cost of credit including fees (עלות אשראי שנתית), in %
    let effectiveAnnualCost: Double?
    let schedule: [AmortizationRow]

    var isCpiLinked: Bool { annualInflationPercent != 0 }
}

/// Core loan calculation engine
enum LoanCalculator {
    // Limits matching Mimun Yashir's consumer / car loans
    static let minPrincipal = 15_000.0
    static let maxPrincipal = 400_000.0
    static let minMonths = 12
    static let maxMonths = 100
    /// Grace period length used by Mimun Yashir
    static let defaultGraceMonths = 3

    /// PMT = P × r / (1 − (1 + r)^(−n))
    static func annuity(balance: Double, monthlyRate: Double, months: Int) -> Double {
        guard balance > 0, months > 0 else { return 0 }
        guard monthlyRate > 0 else { return balance / Double(months) }
        return balance * monthlyRate / (1 - pow(1 + monthlyRate, -Double(months)))
    }

    /// Simulates the loan month by month:
    ///   1. CPI linkage: the balance is indexed by the monthly inflation.
    ///   2. Interest is charged on the (indexed) balance.
    ///   3. The payment depends on the repayment type:
    ///      - Spitzer: annuity on the current balance over the remaining months.
    ///      - Balloon: interest only; the last payment adds the whole balance.
    ///      - Grace: nothing during the grace months (interest is added to the
    ///        balance), then Spitzer over the remaining months.
    static func calculate(
        principal: Double,
        prime: Double,
        margin: Double,
        months: Int,
        repaymentType: RepaymentType = .spitzer,
        fee: Double = 0,
        annualInflationPercent: Double = 0,
        graceMonths: Int = defaultGraceMonths
    ) -> LoanResult {
        let annualRate = prime + margin
        let monthlyRate = annualRate / 100 / 12
        let monthlyInflation = annualInflationPercent == 0
            ? 0
            : pow(1 + annualInflationPercent / 100, 1.0 / 12) - 1
        let grace = repaymentType == .grace ? min(graceMonths, months - 1) : 0

        var rows: [AmortizationRow] = []
        var balance = principal
        var totalLinkage = 0.0

        for month in stride(from: 1, through: months, by: 1) {
            let linkage = balance * monthlyInflation
            balance += linkage
            totalLinkage += linkage

            let interest = balance * monthlyRate
            let remaining = months - month + 1

            let payment: Double
            if month <= grace {
                payment = 0 // interest accrues and is added to the balance
            } else if repaymentType == .balloon {
                payment = month == months ? interest + balance : interest
            } else {
                payment = annuity(balance: balance, monthlyRate: monthlyRate, months: remaining)
            }

            balance -= payment - interest
            if abs(balance) < 0.01 { balance = 0 }

            rows.append(AmortizationRow(
                month: month,
                payment: payment,
                interestPortion: interest,
                principalPortion: max(0, payment - interest),
                linkage: linkage,
                remainingBalance: balance
            ))
        }

        let totalInstallments = rows.reduce(0) { $0 + $1.payment }

        return LoanResult(
            principal: principal,
            annualRate: annualRate,
            months: months,
            repaymentType: repaymentType,
            graceMonths: grace,
            fee: fee,
            annualInflationPercent: annualInflationPercent,
            monthlyPayment: rows.isEmpty ? 0 : rows[min(grace, rows.count - 1)].payment,
            finalPayment: rows.last?.payment ?? 0,
            totalInstallments: totalInstallments,
            totalLinkage: totalLinkage,
            totalInterest: totalInstallments - principal - totalLinkage,
            totalPaid: totalInstallments + fee,
            effectiveAnnualCost: effectiveAnnualRate(
                netReceived: principal - fee,
                payments: rows.map(\.payment)
            ),
            schedule: rows
        )
    }

    /// The largest loan a monthly payment supports, in whole shekels.
    ///
    /// The payment is proportional to the principal on every track, so one
    /// probe loan gives the ratio. Nil when the track has no monthly payment
    /// to size the loan by (a balloon loan at zero interest).
    static func principal(
        forMonthlyPayment target: Double,
        prime: Double,
        margin: Double,
        months: Int,
        repaymentType: RepaymentType = .spitzer,
        annualInflationPercent: Double = 0
    ) -> Double? {
        let probe = 100_000.0
        let payment = calculate(
            principal: probe, prime: prime, margin: margin, months: months,
            repaymentType: repaymentType, annualInflationPercent: annualInflationPercent
        ).monthlyPayment
        guard target > 0, payment > 0 else { return nil }
        return (target * probe / payment).rounded(.down)
    }

    /// Effective annual cost of credit, in percent.
    ///
    /// Finds the monthly rate i at which the money actually received equals
    /// the present value of all payments, then compounds it: (1 + i)^12 − 1.
    /// Returns nil when it cannot be computed.
    static func effectiveAnnualRate(netReceived: Double, payments: [Double]) -> Double? {
        guard netReceived > 0, !payments.isEmpty else { return nil }

        // Runs on every slider step, so the discount is built up by
        // multiplying, not with pow for each month
        func presentValue(_ i: Double) -> Double {
            let step = 1 / (1 + i)
            var discount = step
            var pv = 0.0
            for payment in payments {
                pv += payment * discount
                discount *= step
            }
            return pv
        }

        // presentValue decreases as i grows, so bisection is safe
        var low = -0.5
        var high = 1.0
        guard presentValue(low) >= netReceived, presentValue(high) <= netReceived else {
            return nil
        }
        // Halving 1.5 down to 1e-13 takes about 44 steps; more add nothing
        while high - low > 1e-13 {
            let mid = (low + high) / 2
            if presentValue(mid) > netReceived {
                low = mid
            } else {
                high = mid
            }
        }
        return (pow(1 + (low + high) / 2, 12) - 1) * 100
    }
}
