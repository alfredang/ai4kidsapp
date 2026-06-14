import SwiftUI

/// Brain Games — a classic memory match. Cards are dealt face-down; the child
/// flips two at a time to find matching emoji pairs. Matching all pairs earns
/// stars scaled to how few moves it took. Great for all ages.
struct BrainGamesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress

    private struct Card: Identifiable { let id = UUID(); let face: String; var matched = false }

    private static let faces = ["🐶", "🐱", "🦊", "🐼", "🦁", "🐸", "🐵", "🐯"]

    @State private var cards: [Card] = []
    @State private var flipped: [Int] = []
    @State private var moves = 0
    @State private var busy = false
    @State private var showCelebration = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                topBar
                Text("Find all the matching pairs!")
                    .font(Theme.rounded(22, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        cardView(card, index: index)
                    }
                }
                .frame(maxWidth: 560)
                Text("Moves: \(moves)")
                    .font(Theme.rounded(20, .bold)).foregroundStyle(Theme.ink.opacity(0.7))
                KidButton(title: "New Game", systemImage: "shuffle", color: Theme.green) { deal() }
            }
            .padding(28)
            .frame(maxWidth: .infinity)

            if showCelebration {
                CelebrationView(message: "All matched in \(moves) moves!")
                    .onTapGesture { deal() }
            }
        }
        .onAppear(perform: deal)
    }

    private var topBar: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Brain Games").font(Theme.display(28)).foregroundStyle(Theme.ink)
            Spacer()
            StarBadge(count: progress.stars(for: .brain))
        }
    }

    private func cardView(_ card: Card, index: Int) -> some View {
        let isUp = card.matched || flipped.contains(index)
        return Button {
            flip(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUp ? Color.white : Theme.purple)
                    .softShadow()
                if isUp {
                    Text(card.face).font(.system(size: 52))
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 36, weight: .heavy)).foregroundStyle(.white)
                }
            }
            .frame(width: 110, height: 110)
            .opacity(card.matched ? 0.45 : 1)
            .rotation3DEffect(.degrees(isUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.25), value: isUp)
        }
        .buttonStyle(.plain)
        .disabled(card.matched || busy)
    }

    private func deal() {
        showCelebration = false
        flipped = []
        moves = 0
        busy = false
        let pairs = (Self.faces + Self.faces).map { Card(face: $0) }
        cards = pairs.shuffled()
    }

    private func flip(_ index: Int) {
        guard !busy, !flipped.contains(index), !cards[index].matched else { return }
        flipped.append(index)
        if flipped.count == 2 {
            moves += 1
            let (a, b) = (flipped[0], flipped[1])
            if cards[a].face == cards[b].face {
                cards[a].matched = true
                cards[b].matched = true
                flipped = []
                if cards.allSatisfy(\.matched) { finish() }
            } else {
                busy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    flipped = []
                    busy = false
                }
            }
        }
    }

    private func finish() {
        // Fewer moves → more stars (3 for a great game, down to 1).
        let stars = moves <= 12 ? 3 : (moves <= 18 ? 2 : 1)
        progress.award(stars, to: .brain)
        withAnimation { showCelebration = true }
    }
}
