import Foundation
import Observation

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
        static let inflation = "1.6"
        /// Most consumer loans are linked, so the switch starts on
        static let cpiLinked = true
        /// When the default prime rate was last checked
        static let primeAsOf = "11/2026"
    }

    static let minTarget = 200.0
    static let maxTarget = 10_000.0

    var mode: CalcMode { didSet { save(mode.rawValue, "mode"); recompute() } }
    var targetText: String { didSet { save(targetText, "target"); recompute() } }

    var principalText: String { didSet { save(principalText, "principal"); recompute() } }
    var monthsText: String { didSet { save(monthsText, "months"); recompute() } }
    var primeText: String { didSet { save(primeText, "prime"); recompute() } }
    var marginText: String { didSet { save(marginText, "margin"); recompute() } }
    var inflationText: String { didSet { save(inflationText, "inflation"); recompute() } }
    var track: RepaymentType { didSet { save(track.rawValue, "track"); recompute() } }
    var cpiLinked: Bool { didSet { defaults.set(cpiLinked, forKey: "cpi"); recompute() } }

    /// The answer for the inputs as they are, nil while any is missing or
    /// out of range. Worked out once per change, not on every read, and
    /// published only when it actually changes, so the views showing it
    /// redraw only then.
    private(set) var result: LoanResult?
    /// The last valid answer. It holds the layout while an input is out of
    /// range, with --- in place of the numbers.
    private(set) var lastResult: LoanResult?

    /// The latest index from the Central Bureau of Statistics, once fetched
    private(set) var cpi: CPIReading? {
        didSet { defaults.set(cpi.flatMap { try? JSONEncoder().encode($0) }, forKey: "cbsCPI") }
    }

    /// True while the inflation field holds the published rate, not one the
    /// user typed
    var inflationIsFromCBS: Bool { cpi.map { $0.text == inflationText } ?? false }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: "mode").flatMap(CalcMode.init) ?? .payment
        targetText = defaults.string(forKey: "target") ?? Defaults.target
        principalText = defaults.string(forKey: "principal") ?? Defaults.principal
        monthsText = defaults.string(forKey: "months") ?? Defaults.months
        primeText = defaults.string(forKey: "prime") ?? Defaults.prime
        marginText = defaults.string(forKey: "margin") ?? Defaults.margin
        inflationText = defaults.string(forKey: "inflation") ?? Defaults.inflation
        track = defaults.string(forKey: "track").flatMap(RepaymentType.init) ?? .spitzer
        cpiLinked = defaults.object(forKey: "cpi") as? Bool ?? Defaults.cpiLinked
        cpi = defaults.data(forKey: "cbsCPI").flatMap { try? JSONDecoder().decode(CPIReading.self, from: $0) }
        // Left by features that have been removed: comparison, and the fee
        defaults.removeObject(forKey: "saved")
        defaults.removeObject(forKey: "fee")
        recompute()
    }

    private func recompute() {
        let new = computedResult
        if new != result { result = new }
        if let new, new != lastResult { lastResult = new }
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
        inflationText = cpi?.text ?? Defaults.inflation
        track = .spitzer
        cpiLinked = Defaults.cpiLinked
    }

    // MARK: The published inflation rate

    /// Fetches the latest index, at most twice a day. Without a connection
    /// nothing changes: the field keeps its last value and stays editable.
    func refreshCPI(now: Date = .now,
                    fetch: () async throws -> CPIReading = { try await CBS.latest() }) async {
        let last = defaults.object(forKey: "cbsFetchedAt") as? Date
        if let last, now.timeIntervalSince(last) < 12 * 60 * 60 { return }
        guard let reading = try? await fetch() else { return }
        defaults.set(now, forKey: "cbsFetchedAt")
        apply(reading)
    }

    /// Takes in a new reading. The field follows it unless the user typed
    /// a rate of their own.
    func apply(_ reading: CPIReading) {
        let untouched = inflationText == Defaults.inflation || inflationIsFromCBS
        cpi = reading
        if untouched { inflationText = reading.text }
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

    var inflationError: String? {
        guard cpiLinked else { return nil }
        guard let v = Fmt.parse(inflationText) else { return "הזינו שיעור מדד משוער" }
        if v < -10 || v > 30 { return "מינוס 10% עד 30%" }
        return nil
    }

    private var computedResult: LoanResult? {
        let errors = [
            principalError, targetError, monthsError, primeError, marginError, inflationError,
        ]
        guard errors.allSatisfy({ $0 == nil }),
              let principal = principalValue,
              let months = Int(monthsText),
              let prime = Fmt.parse(primeText),
              let margin = Fmt.parse(marginText)
        else { return nil }

        return LoanCalculator.calculate(
            principal: principal,
            prime: prime,
            margin: margin,
            months: months,
            repaymentType: track,
            annualInflationPercent: cpiLinked ? (Fmt.parse(inflationText) ?? 0) : 0
        )
    }
}
