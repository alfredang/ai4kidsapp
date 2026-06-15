import SwiftUI

/// Phonics Playground — a letter still appears with three picture choices; the
/// child taps the picture whose name starts with that letter. Correct answers
/// earn a star. Fully offline, no text input required (great for ages 4–6).
struct PhonicsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    /// A letter and the emoji/word that starts with it.
    private struct Item: Equatable { let letter: String; let emoji: String; let word: String }

    private static let bank: [Item] = [
        .init(letter: "A", emoji: "🍎", word: "Apple"),
        .init(letter: "B", emoji: "🐻", word: "Bear"),
        .init(letter: "C", emoji: "🐱", word: "Cat"),
        .init(letter: "D", emoji: "🐶", word: "Dog"),
        .init(letter: "E", emoji: "🥚", word: "Egg"),
        .init(letter: "F", emoji: "🐟", word: "Fish"),
        .init(letter: "G", emoji: "🍇", word: "Grapes"),
        .init(letter: "H", emoji: "🏠", word: "House"),
        .init(letter: "K", emoji: "🪁", word: "Kite"),
        .init(letter: "L", emoji: "🦁", word: "Lion"),
        .init(letter: "M", emoji: "🌙", word: "Moon"),
        .init(letter: "S", emoji: "☀️", word: "Sun"),
        .init(letter: "T", emoji: "🌳", word: "Tree"),
        .init(letter: "U", emoji: "☂️", word: "Umbrella"),
    ]

    @State private var target: Item = PhonicsView.bank[0]
    @State private var choices: [Item] = []
    @State private var round = 0
    @State private var correctThisSession = 0
    @State private var wrongPick: Item? = nil
    @State private var showCelebration = false

    private let roundsPerSession = 6

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                topBar
                Spacer()
                Text("Which one starts with…")
                    .font(Theme.rounded(compact ? 20 : 26, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Text(target.letter)
                    .font(.system(size: compact ? 110 : 160, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.pink)
                    .frame(width: compact ? 160 : 220, height: compact ? 160 : 220)
                    .background(Circle().fill(.white))
                    .softShadow()
                Spacer()
                HStack(spacing: compact ? 12 : 24) {
                    ForEach(choices, id: \.word) { item in
                        choiceButton(item)
                    }
                }
                .padding(.horizontal, compact ? 16 : 0)
                Spacer()
            }
            .padding(28)

            if showCelebration {
                CelebrationView(message: "You got \(correctThisSession) right!")
                    .onTapGesture { endSession() }
            }
        }
        .onAppear(perform: newRound)
    }

    private var topBar: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Phonics Playground").font(Theme.display(28)).foregroundStyle(Theme.ink)
            Spacer()
            StarBadge(count: progress.stars(for: .phonics))
        }
    }

    private func choiceButton(_ item: Item) -> some View {
        Button {
            pick(item)
        } label: {
            VStack(spacing: 8) {
                Text(item.emoji).font(.system(size: compact ? 60 : 96))
                Text(item.word)
                    .font(Theme.rounded(compact ? 16 : 22, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: compact ? .infinity : 180)
            .frame(height: compact ? 150 : 200)
            .kidCard()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(wrongPick == item ? Theme.red : .clear, lineWidth: 5))
        }
        .buttonStyle(.plain)
    }

    private func newRound() {
        wrongPick = nil
        target = Self.bank.randomElement()!
        var pool = Self.bank.filter { $0.letter != target.letter }.shuffled()
        choices = (Array(pool.prefix(2)) + [target]).shuffled()
    }

    private func pick(_ item: Item) {
        guard wrongPick == nil else { return }
        if item == target {
            progress.award(1, to: .phonics)
            correctThisSession += 1
            round += 1
            if round >= roundsPerSession {
                withAnimation { showCelebration = true }
            } else {
                withAnimation { newRound() }
            }
        } else {
            withAnimation { wrongPick = item }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { wrongPick = nil }
            }
        }
    }

    private func endSession() {
        round = 0
        correctThisSession = 0
        showCelebration = false
        newRound()
    }
}
