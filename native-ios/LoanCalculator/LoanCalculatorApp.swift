import SwiftUI

@main
struct LoanCalculatorApp: App {
    @State private var store = LoanStore()

    var body: some Scene {
        WindowGroup {
            CalculatorView(store: store)
                // Hebrew only: always right to left, whatever the phone's language
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Fmt.hebrew)
        }
    }
}
