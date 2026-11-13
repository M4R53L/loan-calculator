import SwiftUI

struct CalculatorView: View {
    @Bindable var store: LoanStore
    @FocusState private var focus: Field?
    /// Bumped on every slider step, to tick the haptic engine
    @State private var ticks = 0
    /// The pinned bar only shows once the headline figure scrolls away
    @State private var heroVisible = true
    @State private var confirmingReset = false

    enum Field: Hashable {
        case principal, target, months, prime, margin, fee, inflation
    }

    var body: some View {
        let result = store.result

        NavigationStack {
            // The whole calculator is meant to fit one screen: fields share
            // rows, and each slider sits in the row of the field it drives.
            Form {
                Section {
                    Group {
                        if let result {
                            LoanHero(result: result, mode: store.mode)
                        } else {
                            NoResult()
                        }
                    }
                    // Hidden once the figure has slid under the navigation bar
                    .onGeometryChange(for: Bool.self) { proxy in
                        proxy.frame(in: .global).maxY > 110
                    } action: { visible in
                        heroVisible = visible
                    }
                    .onAppear { heroVisible = true }
                    .onDisappear { heroVisible = false }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                loanSection
                termsSection

                if let result {
                    ResultSections(result: result, store: store)
                }
            }
            .listSectionSpacing(12)
            .contentMargins(.top, 4, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            // Not .interactively: dragging the keyboard down by hand leaves a stale
            // keyboard inset behind, which shows as a gap under the payment bar.
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("מחשבון הלוואה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The question being asked takes the title's place
                ToolbarItem(placement: .principal) {
                    Picker("מה לחשב", selection: $store.mode.animation(.snappy)) {
                        ForEach(CalcMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 230)
                }
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

    /// Amount (or target payment) and term, each with its slider
    private var loanSection: some View {
        Section {
            switch store.mode {
            case .payment:
                VStack(spacing: 0) {
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
                }
            case .borrow:
                VStack(spacing: 0) {
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
            }

            VStack(spacing: 0) {
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
            }
        }
        .listRowBackground(Color.card)
    }

    /// Rates, fee and linkage in two columns, then the repayment track
    private var termsSection: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                          GridItem(.flexible(), alignment: .topLeading)],
                alignment: .leading, spacing: 14
            ) {
                InputCell(
                    // The app works offline, so the prime rate is typed in.
                    // Date the default, so a stale one is noticed.
                    label: store.primeText == LoanStore.Defaults.prime
                        ? "פריים, נכון ל־\(LoanStore.Defaults.primeAsOf)" : "ריבית פריים",
                    unit: "%",
                    text: decimalBinding(\.primeText),
                    error: store.primeError,
                    field: .prime, focus: $focus, keyboard: .decimalPad
                )
                InputCell(
                    label: "מרווח מעל הפריים", unit: "%",
                    text: decimalBinding(\.marginText),
                    error: store.marginError,
                    field: .margin, focus: $focus, keyboard: .decimalPad
                )
                InputCell(
                    label: "עמלת פתיחת תיק", unit: "₪",
                    text: wholeBinding(\.feeText, .fee),
                    error: store.feeError,
                    field: .fee, focus: $focus
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("צמוד למדד")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("צמוד למדד", isOn: $store.cpiLinked.animation(.snappy))
                        .labelsHidden()
                }
                if store.cpiLinked {
                    InputCell(
                        label: "מדד שנתי משוער", unit: "%",
                        text: decimalBinding(\.inflationText, allowNegative: true),
                        error: store.inflationError,
                        field: .inflation, focus: $focus, keyboard: .numbersAndPunctuation
                    )
                }
            }
            .padding(.vertical, 2)

            Picker("מסלול החזר", selection: $store.track) {
                ForEach(RepaymentType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Color.card)
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

/// A full-width field: label on the leading side, the editable number and
/// its unit on the trailing side, and any error underneath. Tapping anywhere
/// on it starts editing.
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
                    .fontWeight(.medium)
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

/// A half-width field for the two-column grid: small label on top, the
/// number and its unit under it.
private struct InputCell: View {
    let label: String
    let unit: String
    @Binding var text: String
    let error: String?
    let field: CalculatorView.Field
    var focus: FocusState<CalculatorView.Field?>.Binding
    var keyboard: UIKeyboardType = .numberPad

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                TextField(label, text: $text, prompt: Text("0"))
                    .keyboardType(keyboard)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .focused(focus, equals: field)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("field.\(field)")
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 31) // lines up with the toggle in the next cell
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
