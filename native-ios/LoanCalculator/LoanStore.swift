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

/// The form's state. Inputs stay as the text the user typed, are validated
/// live, and are remembered between launches.
@MainActor
@Observable
final class LoanStore {
    enum Defaults {
        static let principal = "50,000"
        static let months = "60"
        static let prime = "4.75"
        static let margin = "6.75"
        static let fee = "490"
        static let inflation = "3"
    }

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

    func reset() {
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
        guard let v = Fmt.parse(principalText) else { return "הזינו את סכום ההלוואה" }
        if v < LoanCalculator.minPrincipal || v > LoanCalculator.maxPrincipal {
            return "הסכום צריך להיות 15,000 עד 400,000 ₪"
        }
        return nil
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
        if let principal = Fmt.parse(principalText), fee >= principal {
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
        let errors = [principalError, monthsError, primeError, marginError, feeError, inflationError]
        guard errors.allSatisfy({ $0 == nil }),
              let principal = Fmt.parse(principalText),
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
