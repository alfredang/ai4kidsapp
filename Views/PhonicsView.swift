import SwiftUI

/// Phonics Quest — an adventure map of phonics "worlds", each a quick mini-game
/// (Pop the Phoneme, Build the Word, Rhyme Time, Listen & Find, Sound Blender,
/// Buddy Sounds). Clearing a world unlocks the next and earns up to 3 stars.
/// Whole words are spoken on-device and isolated sounds play bundled clips, so
/// the quest runs fully offline. SwiftUI port of the Android `PhonicsScreen`.
struct PhonicsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var store = PhonicsStageStore()
    @State private var audio = PhonicsAudio()
    @State private var selected: Int?

    private var compact: Bool { hSize == .compact }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let index = selected {
                PhonicsStageHost(index: index, store: store, audio: audio) {
                    audio.stop()
                    selected = nil
                }
                .id(index)
            } else {
                adventureMap
            }
        }
        .onDisappear { audio.stop() }
    }

    // MARK: - Adventure map

    private var columns: [GridItem] {
        compact ? [GridItem(.flexible(), spacing: 16)]
                : [GridItem(.adaptive(minimum: 300), spacing: 16)]
    }

    private var adventureMap: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                    StarBadge(count: store.totalStars)
                }
                Text("Phonics Quest")
                    .font(Theme.display(compact ? 32 : 40))
                    .foregroundStyle(Theme.pink)
                Text("Travel the worlds and master every sound!")
                    .font(Theme.rounded(16, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(PhonicsContent.stages.enumerated()), id: \.element.id) { i, stage in
                        StageNode(
                            stage: stage,
                            number: i + 1,
                            stars: store.stars(for: stage.id),
                            unlocked: store.isUnlocked(i)
                        ) {
                            if store.isUnlocked(i) { selected = i }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(compact ? 18 : 24)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
    }
}

/// One world card on the adventure map.
private struct StageNode: View {
    let stage: PhonicsStage
    let number: Int
    let stars: Int
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(unlocked ? stage.color : Theme.ink.opacity(0.15))
                        .frame(width: 64, height: 64)
                    if unlocked {
                        Text(stage.emoji).font(.system(size: 32))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("World \(number) · \(stage.title)")
                        .font(Theme.rounded(19, .black))
                        .foregroundStyle(unlocked ? Theme.ink : Theme.ink.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(unlocked ? stage.subtitle : "Clear the world before to unlock")
                        .font(Theme.rounded(14, .medium))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .lineLimit(2)
                    if unlocked {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { s in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(s < stars ? Theme.yellow : Theme.ink.opacity(0.15))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                if unlocked {
                    Text("▶")
                        .font(Theme.rounded(22, .black))
                        .foregroundStyle(stage.color)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kidCard()
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
    }
}

// MARK: - Stage host

/// Canned praise per star tier, spoken and shown on clearing a world.
/// Hardcoded on purpose: a celebration must be instant.
private let phonicsPraise: [Int: String] = [
    3: "Perfect! You cleared every round!",
    2: "Great job! You're getting really good at this!",
    1: "Well done! Keep practising and you'll be a superstar!",
]

/// Drives one world: header + progress bar + the active mini-game, then the
/// completion overlay with stars, praise, and Play again / Map.
struct PhonicsStageHost: View {
    @Environment(ProgressStore.self) private var progress

    let index: Int
    let store: PhonicsStageStore
    let audio: PhonicsAudio
    let onBack: () -> Void

    @State private var round = 0
    @State private var total = 1
    @State private var earned: Int?
    @State private var attempt = 0

    private var stage: PhonicsStage { PhonicsContent.stages[index] }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                header
                progressBar
                ScrollView {
                    game
                        .id(attempt) // "Play again" restarts the game fresh.
                        .padding(.vertical, 8)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)

            if let stars = earned {
                completionOverlay(stars: stars)
            }
        }
    }

    private var header: some View {
        HStack {
            CloseButton { audio.stop(); onBack() }
            Spacer()
            Text("\(stage.emoji) \(stage.title)")
                .font(Theme.rounded(20, .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            StarBadge(count: store.stars(for: stage.id))
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Round \(round + 1) of \(total)")
                .font(Theme.rounded(13, .bold))
                .foregroundStyle(Theme.ink.opacity(0.55))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.1))
                    Capsule()
                        .fill(stage.color)
                        .frame(width: geo.size.width * min(1, CGFloat(round + 1) / CGFloat(max(total, 1))))
                        .animation(.spring(duration: 0.4), value: round)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: 640)
    }

    @ViewBuilder
    private var game: some View {
        let onProgress: (Int, Int) -> Void = { r, t in round = r; total = t }
        switch stage.kind {
        case .pop:
            PopPhonemeGame(rounds: stage.pop, color: stage.color, audio: audio,
                           onProgress: onProgress, onFinish: finish)
        case .build:
            BuildWordGame(rounds: stage.build, color: stage.color, audio: audio,
                          onProgress: onProgress, onFinish: finish)
        case .rhyme:
            RhymeGame(rounds: stage.rhyme, color: stage.color, audio: audio,
                      onProgress: onProgress, onFinish: finish)
        case .listen:
            ListenFindGame(rounds: stage.listen, color: stage.color, audio: audio,
                           onProgress: onProgress, onFinish: finish)
        case .blend:
            BlendGame(rounds: stage.blend, color: stage.color, audio: audio,
                      onProgress: onProgress, onFinish: finish)
        case .digraph:
            DigraphGame(rounds: stage.digraph, color: stage.color, audio: audio,
                        onProgress: onProgress, onFinish: finish)
        }
    }

    /// Score the run: persist the stage best, grow the global tally only by the
    /// improvement (never negative), then celebrate.
    private func finish(mistakes: Int) {
        let stars = PhonicsContent.starsForMistakes(mistakes)
        let delta = store.record(stage.id, earned: stars)
        if delta > 0 { progress.award(delta, to: .phonics) }
        withAnimation { earned = stars }
        if let praise = phonicsPraise[stars] { audio.speak(praise) }
    }

    private func completionOverlay(stars: Int) -> some View {
        ZStack {
            CelebrationView(message: "\(stage.title) cleared!")
            VStack {
                Spacer()
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { s in
                            Image(systemName: "star.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(s < stars ? Theme.yellow : Theme.ink.opacity(0.15))
                        }
                    }
                    if let praise = phonicsPraise[stars] {
                        Text(praise)
                            .font(Theme.rounded(15, .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(stage.color.opacity(0.12)))
                    }
                    HStack(spacing: 12) {
                        KidButton(title: "Play again", color: Theme.ink.opacity(0.5)) {
                            earned = nil
                            round = 0
                            attempt += 1
                        }
                        KidButton(title: "Map", color: stage.color) { onBack() }
                    }
                }
                .padding(24)
                .frame(maxWidth: 420)
                .kidCard()
                .padding(24)
            }
        }
    }
}
