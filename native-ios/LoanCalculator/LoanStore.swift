import Foundation
import Observation

/// A loan the user pinned, to compare the current inputs against.
struct SavedScenario: Codable, Equatable, Sendable {
    let principal: Double
    let months: Int
    let repaymentType: RepaymentType
    let annualRate: Double
    let monthlyPayment: Double
    let totalPaid: Double

    init(_ r: LoanResult) {
        principal = r.principal
        months = r.months
        repaymentType = r.repaymentType
        annualRate = r.annualRate
        monthlyPayment = r.monthlyPayment
        totalPaid = r.totalPaid
    }
}

/// Which question the calculator answers
enum CalcMode: String, CaseIterable, Identifiable, Sendable {
    /// Loan amount in, monthly payment out
    case payment
    /// Affordable monthly payment in, loan amount out
    case borrow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .payment: "כמה אשלם"
        case .borrow: "כמה אלווה"
        }
    }
}

/// The form's state. Inputs stay as the text the user typed, are validated
/// live, and are remembered between launches.
@MainActor
@Observable
final class LoanStore {
    enum Defaults {
        static let principal = "50,000"
        static let target = "1,000"
        static let months = "60"
        static let prime = "4.75"
        static let margin = "6.75"
        static let fee = "490"
        static let inflation = "3"
        /// When the default prime rate was last checked
        static let primeAsOf = "11/2026"
    }

    static let minTarget = 200.0
    static let maxTarget = 10_000.0

    var mode: CalcMode { didSet { save(mode.rawValue, "mode") } }
    var targetText: String { didSet { save(targetText, "target") } }

    var principalText: String { didSet { save(principalText, "principal") } }
    var monthsText: String { didSet { save(monthsText, "months") } }
    var primeText: String { didSet { save(primeText, "prime") } }
    var marginText: String { didSet { save(marginText, "margin") } }
    var feeText: String { didSet { save(feeText, "fee") } }
    var inflationText: String { didSet { save(inflationText, "inflation") } }
    var track: RepaymentType { didSet { save(track.rawValue, "track") } }
    var cpiLinked: Bool { didSet { defaults.set(cpiLinked, forKey: "cpi") } }
    var saved: SavedScenario? {
        didSet {
            if let saved, let data = try? JSONEncoder().encode(saved) {
                defaults.set(data, forKey: "saved")
            } else {
                defaults.removeObject(forKey: "saved")
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: "mode").flatMap(CalcMode.init) ?? .payment
        targetText = defaults.string(forKey: "target") ?? Defaults.target
        principalText = defaults.string(forKey: "principal") ?? Defaults.principal
        monthsText = defaults.string(forKey: "months") ?? Defaults.months
        primeText = defaults.string(forKey: "prime") ?? Defaults.prime
        marginText = defaults.string(forKey: "margin") ?? Defaults.margin
        feeText = defaults.string(forKey: "fee") ?? Defaults.fee
        inflationText = defaults.string(forKey: "inflation") ?? Defaults.inflation
        track = defaults.string(forKey: "track").flatMap(RepaymentType.init) ?? .spitzer
        cpiLinked = defaults.bool(forKey: "cpi")
        saved = defaults.data(forKey: "saved")
            .flatMap { try? JSONDecoder().decode(SavedScenario.self, from: $0) }
    }

    private func save(_ value: String, _ key: String) {
        defaults.set(value, forKey: key)
    }

    /// Restores the default inputs. The chosen question stays as it is.
    func reset() {
        targetText = Defaults.target
        principalText = Defaults.principal
        monthsText = Defaults.months
        primeText = Defaults.prime
        marginText = Defaults.margin
        feeText = Defaults.fee
        inflationText = Defaults.inflation
        track = .spitzer
        cpiLinked = false
    }

    // MARK: Validation. Each message is shown under its own field.

    var principalError: String? {
        guard mode == .payment else { return nil }
        guard let v = Fmt.parse(principalText) else { return "הזינו את סכום ההלוואה" }
        if v < LoanCalculator.minPrincipal || v > LoanCalculator.maxPrincipal {
            return "הסכום צריך להיות 15,000 עד 400,000 ₪"
        }
        return nil
    }

    /// The loan a target payment supports. Nil unless the term and rates
    /// are valid, or when the track has no monthly payment to size it by.
    private var borrowable: Double? {
        guard monthsError == nil, primeError == nil, marginError == nil, inflationError == nil,
              let target = Fmt.parse(targetText),
              let months = Int(monthsText),
              let prime = Fmt.parse(primeText),
              let margin = Fmt.parse(marginText)
        else { return nil }
        return LoanCalculator.principal(
            forMonthlyPayment: target, prime: prime, margin: margin, months: months,
            repaymentType: track,
            annualInflationPercent: cpiLinked ? (Fmt.parse(inflationText) ?? 0) : 0
        )
    }

    var targetError: String? {
        guard mode == .borrow else { return nil }
        guard let target = Fmt.parse(targetText), target > 0 else { return "הזינו תשלום חודשי" }
        // Wait for the other fields before judging the payment
        guard monthsError == nil, primeError == nil, marginError == nil, inflationError == nil else {
            return nil
        }
        guard let amount = borrowable else { return "במסלול הזה אין תשלום חודשי לחשב לפיו" }
        if amount < LoanCalculator.minPrincipal {
            return "בתשלום הזה אפשר ללוות \(Fmt.money(amount, cents: false)). המינימום הוא 15,000 ₪"
        }
        if amount > LoanCalculator.maxPrincipal {
            return "התשלום הזה מתאים ליותר מ־400,000 ₪, מעל המקסימום"
        }
        return nil
    }

    /// The loan amount in play: typed in, or worked out from the payment
    private var principalValue: Double? {
        mode == .borrow ? borrowable : Fmt.parse(principalText)
    }

    var monthsError: String? {
        guard let v = Int(monthsText) else { return "הזינו מספר חודשים" }
        if v < LoanCalculator.minMonths || v > LoanCalculator.maxMonths {
            return "12 עד 100 חודשים"
        }
        return nil
    }

    var primeError: String? {
        Fmt.parse(primeText) == nil ? "הזינו ריבית פריים" : nil
    }

    var marginError: String? {
        guard let margin = Fmt.parse(marginText) else { return "הזינו מרווח" }
        if (Fmt.parse(primeText) ?? 0) + margin > 50 {
            return "ריבית שנתית מעל 50% אינה סבירה"
        }
        return nil
    }

    var feeError: String? {
        guard let fee = Fmt.parse(feeText) else { return "הזינו עמלה, או 0" }
        if let principal = principalValue, fee >= principal {
            return "העמלה צריכה להיות קטנה מסכום ההלוואה"
        }
        return nil
    }

    var inflationError: String? {
        guard cpiLinked else { return nil }
        guard let v = Fmt.parse(inflationText) else { return "הזינו שיעור מדד משוער" }
        if v < -10 || v > 30 { return "מינוס 10% עד 30%" }
        return nil
    }

    /// Nil while any input is missing or invalid.
    var result: LoanResult? {
        let errors = [
            principalError, targetError, monthsError, primeError, marginError, feeError, inflationError,
        ]
        guard errors.allSatisfy({ $0 == nil }),
              let principal = principalValue,
              let months = Int(monthsText),
              let prime = Fmt.parse(primeText),
              let margin = Fmt.parse(marginText),
              let fee = Fmt.parse(feeText)
        else { return nil }

        return LoanCalculator.calculate(
            principal: principal,
            prime: prime,
            margin: margin,
            months: months,
            repaymentType: track,
            fee: fee,
            annualInflationPercent: cpiLinked ? (Fmt.parse(inflationText) ?? 0) : 0
        )
    }
}
