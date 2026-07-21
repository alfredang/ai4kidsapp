import SwiftUI

/// Brain Arcade — a hub of quick, fully-offline card games for one player.
/// Picking a game opens its player (how-to → board → results). A SwiftUI port
/// of the Android Brain Arcade, solo subset (no sign-in, no network).
struct BrainArcadeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selected: ArcadeGame?

    private var compact: Bool { hSize == .compact }
    private var columns: [GridItem] {
        compact ? [GridItem(.flexible(), spacing: 16)]
                : [GridItem(.adaptive(minimum: 260), spacing: 16)]
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let game = selected {
                player(for: game)
            } else {
                hub
            }
        }
        .onAppear {
            // Optional launch hook (`-openGame make-ten`) to jump straight into a
            // game — handy for capturing App Store screenshots.
            if let slug = UserDefaults.standard.string(forKey: "openGame"),
               let game = ArcadeGame.all.first(where: { $0.slug == slug }) {
                selected = game
            }
        }
    }

    private var hub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                }
                Text("🕹️ Brain Arcade")
                    .font(Theme.display(compact ? 32 : 40)).foregroundStyle(Theme.ink)
                Text("Quick card games you can play right now, on your own.")
                    .font(Theme.rounded(16, .medium)).foregroundStyle(Theme.ink.opacity(0.65))
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ArcadeGame.all) { game in
                        GameCard(game: game) { selected = game }
                    }
                }
                .padding(.top, 4)
            }
            .padding(compact ? 18 : 24)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func player(for game: ArcadeGame) -> some View {
        let close = { selected = nil }
        switch game.slug {
        case "memory-match":
            ArcadePlayer(game: game, showPairs: true, onClose: close,
                         makeEngine: { MemoryEngine(pairs: $0) }) { MemoryBoard(engine: $0) }
        case "tower-tumble":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in TowerTumbleEngine() }) { TowerTumbleBoard(engine: $0) }
        case "number-hunt":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in NumberHuntEngine() }) { NumberHuntBoard(engine: $0) }
        case "beat-the-die":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in BeatDieEngine() }) { BeatDieBoard(engine: $0) }
        case "make-ten":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in MakeTenEngine() }) { MakeTenBoard(engine: $0) }
        case "animal-count":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in AnimalCountEngine() }) { AnimalCountBoard(engine: $0) }
        case "odd-one-out":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in OddOneOutEngine() }) { OddOneOutBoard(engine: $0) }
        case "alphabet-lock":
            ArcadePlayer(game: game, showPairs: false, onClose: close,
                         makeEngine: { _ in AlphabetLockEngine() }) { AlphabetLockBoard(engine: $0) }
        default:
            EmptyView()
        }
    }
}

/// A single game tile on the arcade hub.
private struct GameCard: View {
    let game: ArcadeGame
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(game.emoji).font(.system(size: 30))
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(game.accent.opacity(0.15)))
                    Spacer()
                    Text(game.ages).font(Theme.rounded(12, .bold)).foregroundStyle(game.accent)
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(Capsule().fill(game.accent.opacity(0.15)))
                }
                Text(game.title).font(Theme.rounded(20, .black)).foregroundStyle(Theme.ink)
                Text(game.blurb).font(Theme.rounded(14, .medium)).foregroundStyle(Theme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text("Play ▶").font(Theme.rounded(15, .black)).foregroundStyle(.white)
                    .padding(.vertical, 8).padding(.horizontal, 18)
                    .background(Capsule().fill(game.accent))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .kidCard()
        }
        .buttonStyle(PressableStyle())
    }
}

/// Drives one arcade game across its phases: a "How to play" menu, the live
/// board, and a results card. Generic over the game's engine + board view.
private struct ArcadePlayer<E: ArcadeEngine, Board: View>: View {
    @Environment(ProgressStore.self) private var progress

    let game: ArcadeGame
    let showPairs: Bool
    let onClose: () -> Void
    let makeEngine: (Int) -> E
    @ViewBuilder let board: (E) -> Board

    private enum Phase { case menu, playing, done }
    @State private var phase: Phase = .menu
    @State private var engine: E?
    @State private var startedAt = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var won = false
    @State private var awarded = false
    @State private var pairs = 8

    private let pairChoices = [6, 8, 10, 12]
    private static var starsForWin: Int { 3 }

    var body: some View {
        let over = engine?.isOver ?? false
        ScrollView {
            VStack(spacing: 16) {
                titleBar
                switch phase {
                case .menu: menu
                case .playing: if let engine { board(engine) }
                case .done: results
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: over) { _, isOver in if isOver, phase == .playing { finish() } }
    }

    private var titleBar: some View {
        HStack {
            CloseButton { if phase == .menu { onClose() } else { reset() } }
            Spacer()
            Text("\(game.emoji) \(game.title)").font(Theme.rounded(22, .black)).foregroundStyle(Theme.ink)
            Spacer()
            Color.clear.frame(width: 48, height: 1)
        }
    }

    private var menu: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How to play").font(Theme.rounded(18, .black)).foregroundStyle(Theme.ink)
                ForEach(Array(game.how.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").font(Theme.rounded(14, .bold)).foregroundStyle(game.accent)
                        Text(line).font(Theme.rounded(14, .medium)).foregroundStyle(Theme.ink.opacity(0.7))
                    }
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading).kidCard()

            if showPairs {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How many cards?").font(Theme.rounded(14, .bold)).foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        ForEach(pairChoices, id: \.self) { n in
                            let on = pairs == n
                            Button { pairs = n } label: {
                                Text("\(n * 2)").font(Theme.rounded(16, .bold))
                                    .foregroundStyle(on ? .white : Theme.ink)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Capsule().fill(on ? Theme.purple : Theme.ink.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).kidCard()
            }

            KidButton(title: "🎯 Play Solo", color: Theme.purple) { start() }

            if let best = ArcadeBest.best(game.slug) {
                Text("🏆 Best: \(ArcadeBest.format(best))")
                    .font(Theme.rounded(15, .bold)).foregroundStyle(Theme.orange)
            }
        }
    }

    private var results: some View {
        VStack(spacing: 12) {
            Text(won ? "🏆" : "😮").font(.system(size: 56))
            Text(won ? "You did it!" : "So close!")
                .font(Theme.rounded(24, .black)).foregroundStyle(Theme.ink)
            if won {
                Text("⏱ \(ArcadeBest.format(elapsed))").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink.opacity(0.6))
                if let best = ArcadeBest.best(game.slug) {
                    Text("🏆 Best: \(ArcadeBest.format(best))").font(Theme.rounded(15, .bold)).foregroundStyle(Theme.orange)
                }
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
                    Text("+\(Self.starsForWin) stars").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            KidButton(title: "Play again ▶", color: Theme.pink) { reset() }
        }
        .padding(28).frame(maxWidth: .infinity).kidCard()
    }

    private func start() {
        engine = makeEngine(pairs)
        startedAt = Date()
        awarded = false
        phase = .playing
    }

    private func reset() {
        engine = nil
        phase = .menu
    }

    private func finish() {
        won = !(engine?.lost ?? true)
        elapsed = Date().timeIntervalSince(startedAt)
        if won, !awarded {
            awarded = true
            ArcadeBest.record(game.slug, seconds: elapsed)
            progress.award(Self.starsForWin, to: .brain)
        }
        phase = .done
    }
}
