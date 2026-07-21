import SwiftUI

/// Grown-ups-only gate — a fresh two-number multiplication each time it appears,
/// so it can't be memorised by a child. SwiftUI port of the Android
/// `cards/ParentalGate.kt`. Used in front of the Parents' Corner (which holds
/// the destructive progress reset), per Apple's Kids Category parental-gate
/// pattern. The app itself stays fully offline with no data collection.
struct ParentalGate: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConsent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var a = Int.random(in: 3...9)
    @State private var b = Int.random(in: 11...19)
    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(message)
                        .font(Theme.rounded(17, .medium))
                        .foregroundStyle(Theme.ink.opacity(0.75))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What is \(a) × \(b)?")
                            .font(Theme.rounded(22, .heavy))
                            .foregroundStyle(Theme.ink)
                        TextField("Answer", text: $answer)
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .font(Theme.rounded(22, .bold))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(wrong ? Theme.red : Theme.purple.opacity(0.35), lineWidth: 2))
                        if wrong {
                            Text("Not quite — try the new problem.")
                                .font(Theme.rounded(15, .semibold))
                                .foregroundStyle(Theme.red)
                        }
                    }
                    .padding(20)
                    .kidCard()

                    Button {
                        if Int(answer.trimmingCharacters(in: .whitespaces)) == a * b {
                            onConsent()
                        } else {
                            // New challenge on every miss so guessing doesn't converge.
                            a = Int.random(in: 3...9)
                            b = Int.random(in: 11...19)
                            answer = ""
                            wrong = true
                        }
                    } label: {
                        Text(confirmLabel)
                            .font(Theme.rounded(19, .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Theme.purple))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(answer.isEmpty)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }
}
