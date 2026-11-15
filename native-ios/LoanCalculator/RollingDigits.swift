import SwiftUI

/// A number whose digits roll when they change: the new digit slides in and
/// the old one out, upwards when the number grows and downwards when it
/// shrinks.
///
/// This replaces `.contentTransition(.numericText())`, which blurs the
/// digits as they change and draws that blur on the CPU at full resolution.
/// On the headline that took about half the main thread while a slider was
/// dragged. Here each character is its own text, drawn once; a change only
/// moves and fades them, which the GPU does for free.
///
/// The animation comes from the caller, for example
/// `.animation(.snappy, value: number)`.
struct RollingDigits: View {
    /// Left to right, such as "1,099.63"
    let text: String
    /// Which way to roll. Nil works it out from the change in `text`.
    var rising: Bool? = nil

    @State private var direction = RollDirection()

    var body: some View {
        let up = rising ?? direction.update(Self.number(text))
        // Characters keep their place counted from the right, so the units
        // stay the units when a digit is added at the front
        let characters = Array(text)
        let slots = characters.indices.map { Slot(id: characters.count - 1 - $0, character: characters[$0]) }

        HStack(spacing: 0) {
            ForEach(slots) { slot in
                ZStack {
                    Text(String(slot.character))
                        .id(slot.character)
                        // The old digit leaves quickly, so when a slider
                        // changes the number faster than a roll takes, the
                        // digits do not pile up on each other
                        .transition(AsymmetricTransition(
                            insertion: Roll(up: up),
                            removal: Roll(up: up).animation(.easeOut(duration: 0.1))
                        ))
                }
            }
        }
        .monospacedDigit()
        .fixedSize()
        // Digits roll in and out of their own line, not over what is near
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private struct Slot: Identifiable {
        let id: Int
        let character: Character
    }

    /// "1,099.63" → 1099.63
    /// Pure, so callable from any thread: a view's members are otherwise
    /// tied to the main actor
    nonisolated static func number(_ text: String) -> Double? {
        Double(text.filter { $0.isNumber || $0 == "." || $0 == "-" })
    }
}

/// A digit coming in or going out: it travels under a third of its own
/// height while it fades, so the old digit is gone before it rises past
/// the number into the space a large font keeps above it.
private struct Roll: Transition {
    /// The number grew: new digits come up from below, old ones leave
    /// upwards
    let up: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        // -1 coming in, 0 in place, 1 gone
        let travel = (up ? -1.0 : 1.0) * phase.value * 0.3
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .visualEffect { effect, proxy in
                effect.offset(y: proxy.size.height * travel)
            }
    }
}

/// Remembers the last number, to tell whether the next one is up or down.
/// A plain class, not observed: updating it never redraws anything.
final class RollDirection {
    private var last: Double?
    private var rising = true

    func update(_ value: Double?) -> Bool {
        guard let value else { return rising }
        if let last, value != last { rising = value > last }
        last = value
        return rising
    }
}
