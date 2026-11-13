import SwiftUI

struct CalculatorView: View {
    @Bindable var store: LoanStore
    @FocusState private var focus: Field?
    /// Bumped on every slider step and quick pick, to tick the haptic engine
    @State private var ticks = 0
    /// The pinned bar only shows once the headline figure scrolls away
    @State private var heroVisible = true
    @State private var confirmingReset = false

    enum Field: Hashable {
        case principal, target, months, prime, margin, fee, inflation
    }

    private static let termPicks = [24, 36, 48, 60, 84]

    var body: some View {
        let result = store.result

        NavigationStack {
            Form {
                // The question, then its answer, straight on the canvas
                Section {
                    Picker("מה לחשב", selection: $store.mode.animation(.snappy)) {
                        ForEach(CalcMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    Group {
                        if let result {
                            LoanHero(result: result, mode: store.mode)
                        } else {
                            NoResult()
                        }
                    }
                    .onAppear { heroVisible = true }
                    .onDisappear { heroVisible = false }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))

                loanSection
                rateSection
                trackSection
                feeSection

                if let result {
                    ResultSections(result: result, store: store)
                }
            }
            // Not .interactively: dragging the keyboard down by hand leaves a stale
            // keyboard inset behind, which shows as a gap under the payment bar.
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("מחשבון הלוואה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("איפוס") {
                        focus = nil
                        confirmingReset = true
                    }
                    .confirmationDialog(
                        "לאפס את כל הנתונים לערכי ברירת המחדל?",
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button("איפוס הנתונים", role: .destructive) {
                            withAnimation(.snappy) { store.reset() }
                        }
                        Button("ביטול", role: .cancel) {}
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("סיום") { focus = nil }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let result, !heroVisible {
                    PaymentBar(result: result, mode: store.mode)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: heroVisible)
            .sensoryFeedback(.selection, trigger: ticks)
            .sensoryFeedback(.selection, trigger: store.track)
            .sensoryFeedback(.selection, trigger: store.mode)
            .sensoryFeedback(.selection, trigger: store.cpiLinked)
            .sensoryFeedback(.impact(weight: .light), trigger: store.saved)
        }
    }

    // MARK: Sections

    private var loanSection: some View {
        Section("ההלוואה") {
            switch store.mode {
            case .payment:
                InputRow(
                    label: "סכום ההלוואה", unit: "₪",
                    text: wholeBinding(\.principalText, .principal),
                    error: store.principalError,
                    field: .principal, focus: $focus
                )
                stepSlider(
                    "סכום ההלוואה", text: \.principalText,
                    range: LoanCalculator.minPrincipal...LoanCalculator.maxPrincipal,
                    step: 5000, low: "15 אלף", high: "400 אלף"
                )
            case .borrow:
                InputRow(
                    label: "תשלום חודשי רצוי", unit: "₪",
                    text: wholeBinding(\.targetText, .target),
                    error: store.targetError,
                    field: .target, focus: $focus
                )
                stepSlider(
                    "תשלום חודשי רצוי", text: \.targetText,
                    range: LoanStore.minTarget...LoanStore.maxTarget,
                    step: 50, low: "200", high: "10 אלף"
                )
            }

            InputRow(
                label: "תקופה", unit: "חודשים",
                text: Binding(
                    get: { store.monthsText },
                    set: { store.monthsText = String($0.filter(\.isNumber).prefix(3)) }
                ),
                error: store.monthsError,
                field: .months, focus: $focus
            )
            Slider(
                value: Binding(
                    get: {
                        Double(min(max(Int(store.monthsText) ?? LoanCalculator.minMonths,
                                       LoanCalculator.minMonths), LoanCalculator.maxMonths))
                    },
                    set: { setMonths(Int($0.rounded())) }
                ),
                in: Double(LoanCalculator.minMonths)...Double(LoanCalculator.maxMonths)
            ) {
                Text("תקופה")
            } minimumValueLabel: {
                sliderLabel("12")
            } maximumValueLabel: {
                sliderLabel("100")
            }
            HStack(spacing: 8) {
                ForEach(Self.termPicks, id: \.self) { months in
                    let selected = Int(store.monthsText) == months
                    Button {
                        setMonths(months)
                    } label: {
                        Text("\(months)")
                            .monospacedDigit()
                            .fontWeight(selected ? .semibold : .regular)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? .accentColor : .secondary)
                    .accessibilityLabel("\(months) חודשים")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var rateSection: some View {
        Section {
            InputRow(
                label: "ריבית פריים", unit: "%",
                text: decimalBinding(\.primeText),
                error: store.primeError,
                field: .prime, focus: $focus, keyboard: .decimalPad
            )
            InputRow(
                label: "מרווח מעל הפריים", unit: "%",
                text: decimalBinding(\.marginText),
                error: store.marginError,
                field: .margin, focus: $focus, keyboard: .decimalPad
            )
        } header: {
            Text("ריבית")
        } footer: {
            // The app works offline, so the prime rate is a typed-in figure
            if store.primeText == LoanStore.Defaults.prime {
                Text("\(LoanStore.Defaults.prime)% היא ריבית הפריים נכון ל\(LoanStore.Defaults.primeAsOf). בדקו שלא השתנתה מאז.")
            }
        }
    }

    private var trackSection: some View {
        Section {
            Picker("מסלול החזר", selection: $store.track) {
                ForEach(RepaymentType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("מסלול החזר")
        } footer: {
            Text(trackHint)
        }
    }

    private var feeSection: some View {
        Section {
            InputRow(
                label: "עמלת פתיחת תיק", unit: "₪",
                text: wholeBinding(\.feeText, .fee),
                error: store.feeError,
                field: .fee, focus: $focus
            )
            Toggle(isOn: $store.cpiLinked.animation(.snappy)) {
                Text("צמוד למדד")
                Text("הקרן מתעדכנת לפי מדד המחירים לצרכן")
            }
            if store.cpiLinked {
                InputRow(
                    label: "מדד שנתי משוער", unit: "%",
                    text: decimalBinding(\.inflationText, allowNegative: true),
                    error: store.inflationError,
                    field: .inflation, focus: $focus, keyboard: .numbersAndPunctuation
                )
            }
        } header: {
            Text("עמלות והצמדה")
        } footer: {
            Text(store.cpiLinked
                 ? "העמלה נכללת בעלות האשראי השנתית. המדד הוא הערכה בלבד, והמדד בפועל ישנה את התשלומים."
                 : "העמלה נכללת בעלות האשראי השנתית.")
        }
    }

    private var trackHint: String {
        switch store.track {
        case .spitzer:
            "תשלום קבוע בכל חודש. בהתחלה רובו ריבית, ובהמשך רובו קרן."
        case .balloon:
            "משלמים רק ריבית בכל חודש, ואת כל הקרן בתשלום האחרון."
        case .grace:
            "שלושה חודשים ראשונים בלי תשלומים. הריבית שנצברת מתווספת לחוב ונפרסת על שאר התקופה."
        }
    }

    // MARK: Helpers

    private func sliderLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    /// Slider for a whole-shekel field. It snaps in code: a stepped Slider
    /// draws a tick mark for every step.
    private func stepSlider(
        _ label: String,
        text keyPath: ReferenceWritableKeyPath<LoanStore, String>,
        range: ClosedRange<Double>,
        step: Double,
        low: String,
        high: String
    ) -> some View {
        Slider(
            value: Binding(
                get: {
                    min(max(Fmt.parse(store[keyPath: keyPath]) ?? range.lowerBound,
                            range.lowerBound), range.upperBound)
                },
                set: { new in
                    let text = Fmt.grouped((new / step).rounded() * step)
                    if text != store[keyPath: keyPath] {
                        store[keyPath: keyPath] = text
                        ticks += 1
                    }
                }
            ),
            in: range
        ) {
            Text(label)
        } minimumValueLabel: {
            sliderLabel(low)
        } maximumValueLabel: {
            sliderLabel(high)
        }
    }

    private func setMonths(_ months: Int) {
        let text = String(months)
        if text != store.monthsText {
            store.monthsText = text
            ticks += 1
        }
    }

    /// Whole-shekel field. Thousands separators show only while the field is
    /// not being edited: regrouping under the cursor makes it jump to the end.
    private func wholeBinding(
        _ keyPath: ReferenceWritableKeyPath<LoanStore, String>,
        _ field: Field
    ) -> Binding<String> {
        Binding(
            get: {
                let text = store[keyPath: keyPath]
                return focus == field ? Fmt.ungrouped(text) : text
            },
            set: { store[keyPath: keyPath] = Fmt.sanitizeWhole($0) }
        )
    }

    private func decimalBinding(
        _ keyPath: ReferenceWritableKeyPath<LoanStore, String>,
        allowNegative: Bool = false
    ) -> Binding<String> {
        Binding(
            get: { store[keyPath: keyPath] },
            set: { store[keyPath: keyPath] = Fmt.sanitizeDecimal($0, allowNegative: allowNegative) }
        )
    }
}

/// A form row: label on the leading side, the editable number and its unit
/// on the trailing side, and any error underneath. Tapping anywhere on the
/// row starts editing.
private struct InputRow: View {
    let label: String
    let unit: String
    @Binding var text: String
    let error: String?
    let field: CalculatorView.Field
    var focus: FocusState<CalculatorView.Field?>.Binding
    var keyboard: UIKeyboardType = .numberPad

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                TextField(label, text: $text, prompt: Text("0"))
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused(focus, equals: field)
                    .labelsHidden()
                    .accessibilityIdentifier("field.\(field)")
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
    }
}

/// Keeps the answer in view once the headline has scrolled away.
private struct PaymentBar: View {
    let result: LoanResult
    let mode: CalcMode

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .borrow ? "תוכלו ללוות" : "תשלום חודשי")
                    .font(.subheadline)
                Text("עלות אשראי \(Fmt.percent(result.effectiveAnnualCost ?? result.annualRate))")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            Spacer()
            MoneyText(
                value: mode == .borrow ? result.principal : result.monthlyPayment,
                cents: mode == .payment
            )
            .font(.title2.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paymentBar")
    }
}

/// A shekel amount whose digits roll to the new value.
struct MoneyText: View {
    let value: Double
    var signed = false
    var cents = true

    var body: some View {
        Text(signed ? Fmt.signedMoney(value) : Fmt.money(value, cents: cents))
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(.snappy(duration: 0.3), value: value)
    }
}

#Preview {
    CalculatorView(store: LoanStore())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Fmt.hebrew)
}
