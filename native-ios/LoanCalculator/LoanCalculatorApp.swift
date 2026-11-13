import SwiftUI

@main
struct LoanCalculatorApp: App {
    @State private var store = LoanStore(defaults: LoanCalculatorApp.defaults)

    /// UI tests start from the default inputs, not the last session's
    private static var defaults: UserDefaults {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting"),
              let scratch = UserDefaults(suiteName: "uiTesting")
        else { return .standard }
        scratch.removePersistentDomain(forName: "uiTesting")
        return scratch
    }

    var body: some Scene {
        WindowGroup {
            CalculatorView(store: store)
                // Hebrew only: always right to left, whatever the phone's language
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Fmt.hebrew)
        }
    }
}
