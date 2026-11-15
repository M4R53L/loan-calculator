import SwiftUI

/// The calculator, on one screen.
///
/// Performance: dragging a slider changes the inputs many times a second.
/// This body reads no input and no result, so it is not redrawn for each
/// step. Each part of the screen reads what it shows inside its own `Live`,
/// and only the parts whose data changed are redrawn: for the amount
/// slider, the amount row, the headline and the cost card, but not the
/// other text fields.
struct CalculatorView: View {
    @Bindable var store: LoanStore
    @FocusState private var focus: Field?
    /// Ticks the haptic engine on every slider step. An object, so a tick
    /// redraws only the slider that reads it, not the screen.
    @State private var haptics = SliderHaptics()
    @State private var confirmingReset = false
    @State private var showingDisclaimer = false
    /// The screen's height with no keyboard showing
    @State private var restingHeight: CGFloat = 0

    enum Field: Hashable {
        case principal, target, months, prime, margin, inflation
    }

    var body: some View {
        NavigationStack {
            // The calculator fits one screen. The cards keep their natural
            // height and stay at the bottom, in reach of a thumb. Whatever
            // height is left goes to the headline, which grows to fill it:
            // larger on a Pro Max, smaller on an iPhone 16. It scrolls only
            // when it has to: under the keyboard, or with error messages.
            GeometryReader { screen in
                // Laid out for the screen without the keyboard, so the
                // headline holds its size while a field is edited
                let height = focus == nil
                    ? screen.size.height : max(restingHeight, screen.size.height)
                ScrollView {
                    VStack(spacing: 0) {
                        GeometryReader { slot in
                            Live { hero(fitting: slot.size) }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(minHeight: 110)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                        card {
                            Live { amountRow }
                            Divider()
                            Live { monthsRow }
                        }
                        gap
                        card { Live { termsCard } }
                        Live { costCard }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .frame(minHeight: height, alignment: .top)
                }
                .onChange(of: screen.size.height, initial: true) { _, new in
                    if focus == nil { restingHeight = new }
                }
                .scrollBounceBehavior(.basedOnSize)
                // Not .interactively: dragging the keyboard down by hand leaves a
                // stale keyboard inset behind.
                .scrollDismissesKeyboard(.immediately)
            }
            .background(Color.canvas)
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
                ToolbarItem(placement: .topBarLeading) {
                    Live { shareButton(store.result) }
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
            // Tapping a field selects its number, so typing replaces it.
            // Deferred a turn: UIKit places the cursor after this fires, and
            // the whole-shekel fields drop their separators on focus.
            .onReceive(NotificationCenter.default.publisher(
                for: UITextField.textDidBeginEditingNotification
            )) { note in
                guard let field = note.object as? UITextField else { return }
                Task { @MainActor in field.selectAll(nil) }
            }
            .sensoryFeedback(.selection, trigger: store.track)
            .sensoryFeedback(.selection, trigger: store.mode)
            .sensoryFeedback(.selection, trigger: store.cpiLinked)
        }
    }

    // MARK: Layout

    /// Space between the cards: a little more on taller phones
    private var gap: some View {
        Spacer(minLength: 8)
            .frame(maxHeight: 16)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private func shareButton(_ result: LoanResult?) -> some View {
        let label = Label("שיתוף כתמונה", systemImage: "square.and.arrow.up")
        if let result {
            ShareLink(
                item: LoanImage(result: result, mode: store.mode),
                preview: SharePreview("סיכום הלוואה")
            ) {
                label
            }
        } else {
            Button {} label: { label }
                .disabled(true)
        }
    }

    // MARK: Results

    /// The headline. While an input is out of range the last answer keeps
    /// the layout, showing --- in place of the number, so nothing moves.
    @ViewBuilder
    private func hero(fitting space: CGSize) -> some View {
        if let shown = store.result ?? store.lastResult {
            LoanHero(result: shown, mode: store.mode,
                     figureSize: LoanHero.figureSize(fitting: space, result: shown, mode: store.mode),
                     placeholder: store.result == nil)
        } else {
            NoResult()
        }
    }

    /// What the loan costs, with the gap above it
    @ViewBuilder
    private var costCard: some View {
        if let shown = store.result ?? store.lastResult {
            gap
            card { CostSummary(result: shown, placeholder: store.result == nil) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("costSummary")
        }
        disclaimerButton
    }

    /// Always on screen under the results. Tapping it opens the full text.
    private var disclaimerButton: some View {
        Button {
            focus = nil
            showingDisclaimer = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Disclaimer.short)
                Image(systemName: "info.circle")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("פותח את ההבהרה המלאה")
        .accessibilityIdentifier("disclaimer")
        .sheet(isPresented: $showingDisclaimer) { DisclaimerSheet() }
    }

    // MARK: Cards

    /// Amount (or target payment), with its slider
    @ViewBuilder
    private var amountRow: some View {
        switch store.mode {
        case .payment:
            VStack(spacing: 0) {
                InputRow(
                    label: "סכום ההלוואה", unit: "₪",
                    text: wholeBinding(\.principalText, .principal),
                    field: .principal, focus: $focus
                )
                stepSlider(
                    "סכום ההלוואה", text: \.principalText,
                    range: LoanCalculator.minPrincipal...LoanCalculator.maxPrincipal,
                    step: 5000, low: "15 אלף", high: "400 אלף"
                )
                .replaced(byHint: store.principalError)
            }
        case .borrow:
            VStack(spacing: 0) {
                InputRow(
                    label: "תשלום חודשי רצוי", unit: "₪",
                    text: wholeBinding(\.targetText, .target),
                    field: .target, focus: $focus
                )
                stepSlider(
                    "תשלום חודשי רצוי", text: \.targetText,
                    range: LoanStore.minTarget...LoanStore.maxTarget,
                    step: 50, low: "200", high: "10 אלף"
                )
                .replaced(byHint: store.targetError)
            }
        }
    }

    /// The term, with its slider
    private var monthsRow: some View {
        VStack(spacing: 0) {
            InputRow(
                label: "תקופה", unit: "חודשים",
                text: Binding(
                    get: { store.monthsText },
                    set: { store.monthsText = String($0.filter(\.isNumber).prefix(3)) }
                ),
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
            .replaced(byHint: store.monthsError)
            .sensoryFeedback(.selection, trigger: haptics.monthTicks)
        }
    }

    /// Where the inflation rate came from: the Central Bureau of
    /// Statistics' last 12 months, or the user's own estimate
    private var inflationSource: String? {
        guard store.cpiLinked else { return nil }
        if store.inflationIsFromCBS, let cpi = store.cpi { return "הלמ״ס \(cpi.period)" }
        return "שנתי משוער"
    }

    /// The switch, and beside it the yearly rate, on one line
    private var linkageRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("צמוד למדד")
                    .font(.subheadline)
                // An error takes the source's place, so the row keeps its height
                if let error = store.inflationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .minimumScaleFactor(0.7)
                } else if let inflationSource {
                    Text(inflationSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Toggle("צמוד למדד", isOn: $store.cpiLinked.animation(.snappy))
                    .labelsHidden()
                    .fixedSize() // a bare switch still takes any width it is offered
                // After the switch, so the field's unused width falls at the
                // card's edge and the rate sits beside the switch
                if store.cpiLinked {
                    NumberField(label: "מדד שנתי משוער", unit: "%",
                                text: decimalBinding(\.inflationText, allowNegative: true),
                                field: .inflation, focus: $focus,
                                keyboard: .numbersAndPunctuation, width: 40)
                        .transition(.opacity)
                }
            }
            .lineLimit(1)
        }
    }

    /// The two rates side by side, linkage, then the repayment track
    @ViewBuilder
    private var termsCard: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                InputCell(
                    // The app works offline, so the prime rate is typed in.
                    // Date the default, so a stale one is noticed.
                    label: store.primeText == LoanStore.Defaults.prime
                        ? "פריים, נכון ל־\(LoanStore.Defaults.primeAsOf)" : "ריבית פריים",
                    error: store.primeError
                ) {
                    NumberField(label: "ריבית פריים", unit: "%",
                                text: decimalBinding(\.primeText),
                                field: .prime, focus: $focus, keyboard: .decimalPad)
                }
                InputCell(label: "מרווח מעל הפריים", error: store.marginError) {
                    NumberField(label: "מרווח מעל הפריים", unit: "%",
                                text: decimalBinding(\.marginText),
                                field: .margin, focus: $focus, keyboard: .decimalPad)
                }
            }
        }

        linkageRow

        Divider()

        Picker("מסלול החזר", selection: $store.track) {
            ForEach(RepaymentType.allCases) { type in
                Text(type.label).tag(type)
            }
        }
        .pickerStyle(.segmented)
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
                        haptics.amountTicks += 1
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
        .sensoryFeedback(.selection, trigger: haptics.amountTicks)
    }

    private func setMonths(_ months: Int) {
        let text = String(months)
        if text != store.monthsText {
            store.monthsText = text
            haptics.monthTicks += 1
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

/// Evaluates its content in its own body. The store values the content
/// reads then redraw this part alone, not the view that holds it.
private struct Live<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View { content() }
}

/// Counts slider steps, one counter per slider, to tick the haptic engine
@Observable
private final class SliderHaptics {
    var amountTicks = 0
    var monthTicks = 0
}

/// A full-width field: label on the leading side, the editable number and
/// its unit on the trailing side, and any error underneath. Tapping anywhere
/// on it starts editing.
private struct InputRow: View {
    let label: String
    let unit: String
    @Binding var text: String
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
        }
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
    }
}

/// A half-width cell for the two-column grid: small label on top and the
/// control under it. An error takes the label's place, so the cell keeps
/// its height.
private struct InputCell<Content: View>: View {
    let label: String
    let error: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(error ?? label)
                .font(.caption)
                .foregroundStyle(error == nil ? .secondary : Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            content
                .frame(minHeight: 31) // fields line up with the switch
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A number and its unit. Tapping anywhere on it starts editing.
private struct NumberField: View {
    let label: String
    let unit: String
    @Binding var text: String
    let field: CalculatorView.Field
    var focus: FocusState<CalculatorView.Field?>.Binding
    var keyboard: UIKeyboardType = .numberPad
    /// Fits about seven digits, such as "12.25" or "10,000"
    @ScaledMetric private var width: CGFloat

    init(label: String, unit: String, text: Binding<String>, field: CalculatorView.Field,
         focus: FocusState<CalculatorView.Field?>.Binding,
         keyboard: UIKeyboardType = .numberPad, width: CGFloat = 76) {
        self.label = label
        self.unit = unit
        _text = text
        self.field = field
        self.focus = focus
        self.keyboard = keyboard
        _width = ScaledMetric(wrappedValue: width, relativeTo: .body)
    }

    var body: some View {
        HStack(spacing: 4) {
            // A fixed width, not one sized to the text: a field that grows
            // a frame behind each typed digit scrolls the number out of
            // view and stays scrolled.
            TextField(label, text: $text, prompt: Text("0"))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .fontWeight(.medium)
                .focused(focus, equals: field)
                .labelsHidden()
                .frame(width: width)
                .accessibilityIdentifier("field.\(field)")
            Text(unit)
                .foregroundStyle(.secondary)
        }
        // Numbers read left to right. In the app's right-to-left layout
        // the cursor sat on the left of the digits, so typing landed there.
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
    }
}

#Preview {
    CalculatorView(store: LoanStore())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Fmt.hebrew)
}

private extension View {
    /// While a row's value is out of range, its hint takes the slider's
    /// place, in the same height, so nothing below it moves
    func replaced(byHint hint: String?) -> some View {
        opacity(hint == nil ? 1 : 0)
            .allowsHitTesting(hint == nil)
            .accessibilityHidden(hint != nil)
            .overlay(alignment: .leading) {
                if let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
    }
}

// MARK: Disclaimer

/// What the results are and are not. One wording for the screen, the
/// shared image and the full text.
enum Disclaimer {
    static let short = "החישוב הוא הערכה בלבד ואינו מהווה ייעוץ פיננסי או הצעה לאשראי. התנאים בפועל נקבעים על ידי הגוף המלווה."

    static let points = [
        "החישובים באפליקציה הם הערכה בלבד, לצורכי המחשה. הם אינם מהווים ייעוץ פיננסי, ייעוץ השקעות או המלצה, ואינם הצעה או התחייבות למתן אשראי.",
        "התנאים בפועל, כולל הריבית, התשלום החודשי והעלות הכוללת, נקבעים על ידי הגוף המלווה ותלויים בנתוני הלווה. הם עשויים להיות שונים מהתוצאה כאן.",
        "נתון המדד מגיע מהלשכה המרכזית לסטטיסטיקה ומשקף את 12 החודשים האחרונים. הוא עשוי להתעדכן באיחור או להיות שגוי. המדד העתידי אינו ידוע, ולכן כל חישוב צמוד מדד הוא אומדן.",
        "ייתכנו הבדלים בגלל עיגול, שיטות חישוב שונות, עמלות ותנאים שאינם נכללים בחישוב.",
        "האפליקציה אינה מציעה הלוואות ואינה קשורה לאף גוף מלווה.",
        "השימוש באפליקציה הוא באחריות המשתמש בלבד. המפתח אינו אחראי לכל החלטה או נזק הנובעים מהשימוש בתוצאות. לפני קבלת החלטה, פנו לגוף המלווה או ליועץ מוסמך.",
    ]

    static let termsURL = URL(string: "https://m4r53l.github.io/loan-calculator/privacy.html#terms")!
}

/// The full disclaimer, opened from the line under the results
private struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Disclaimer.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(point)
                        }
                    }
                    Link("תנאי השימוש ומדיניות הפרטיות", destination: Disclaimer.termsURL)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("הבהרה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סגירה") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
