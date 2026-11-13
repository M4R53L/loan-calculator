import SwiftUI

struct CalculatorView: View {
    @Bindable var store: LoanStore
    @FocusState private var focus: Field?
    /// Bumped on every slider step and quick pick, to tick the haptic engine
    @State private var ticks = 0

    enum Field: Hashable {
        case principal, months, prime, margin, fee, inflation
    }

    private static let termPicks = [24, 36, 48, 60, 84]

    var body: some View {
        let result = store.result

        NavigationStack {
            Form {
                loanSection
                rateSection
                trackSection
                feeSection

                if let result {
                    ResultSections(result: result, store: store)
                } else {
                    Section {
                        ContentUnavailableView(
                            "אין עדיין חישוב",
                            systemImage: "plus.forwardslash.minus",
                            description: Text("תקנו את השדות המסומנים, וההחזר החודשי יופיע כאן.")
                        )
                    }
                }
            }
            // Not .interactively: dragging the keyboard down by hand leaves a stale
            // keyboard inset behind, which shows as a gap under the payment bar.
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("מחשבון הלוואה")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("איפוס") {
                        focus = nil
                        withAnimation(.snappy) { store.reset() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("סיום") { focus = nil }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let result {
                    PaymentBar(result: result)
                }
            }
            .sensoryFeedback(.selection, trigger: ticks)
            .sensoryFeedback(.selection, trigger: store.track)
            .sensoryFeedback(.selection, trigger: store.cpiLinked)
            .sensoryFeedback(.impact(weight: .light), trigger: store.saved)
        }
    }

    // MARK: Sections

    private var loanSection: some View {
        Section("ההלוואה") {
            InputRow(
                label: "סכום ההלוואה", unit: "₪",
                text: wholeBinding(\.principalText),
                error: store.principalError,
                field: .principal, focus: $focus
            )
            Slider(
                value: Binding(
                    get: {
                        min(max(Fmt.parse(store.principalText) ?? LoanCalculator.minPrincipal,
                                LoanCalculator.minPrincipal), LoanCalculator.maxPrincipal)
                    },
                    set: { new in
                        // Snap to 5,000 here: a stepped Slider draws a tick per step
                        let text = Fmt.grouped((new / 5000).rounded() * 5000)
                        if text != store.principalText {
                            store.principalText = text
                            ticks += 1
                        }
                    }
                ),
                in: LoanCalculator.minPrincipal...LoanCalculator.maxPrincipal
            ) {
                Text("סכום ההלוואה")
            } minimumValueLabel: {
                Text("15K").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("400K").font(.caption).foregroundStyle(.secondary)
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
                Text("12").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("100").font(.caption).foregroundStyle(.secondary)
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
        Section("ריבית") {
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
                text: wholeBinding(\.feeText),
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

    private func setMonths(_ months: Int) {
        let text = String(months)
        if text != store.monthsText {
            store.monthsText = text
            ticks += 1
        }
    }

    private func wholeBinding(_ keyPath: ReferenceWritableKeyPath<LoanStore, String>) -> Binding<String> {
        Binding(
            get: { store[keyPath: keyPath] },
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

/// Keeps the monthly payment in view while the form is scrolled or edited.
private struct PaymentBar: View {
    let result: LoanResult

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("תשלום חודשי")
                    .font(.subheadline)
                Text("עלות אשראי \(Fmt.percent(result.effectiveAnnualCost ?? result.annualRate))")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            Spacer()
            MoneyText(value: result.monthlyPayment)
                .font(.title2.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

/// A shekel amount whose digits roll to the new value.
struct MoneyText: View {
    let value: Double
    var signed = false

    var body: some View {
        Text(signed ? Fmt.signedMoney(value) : Fmt.money(value))
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
