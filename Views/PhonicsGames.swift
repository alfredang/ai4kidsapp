import SwiftUI

/// The Phonics Quest mini-games. SwiftUI port of the Android `PhonicsGames.kt`
/// (minus the optional Gemini "Buddy" — this app is fully offline, so a canned
/// hint line is shown instead where it helps).

/// Silence held after the last letter finishes, before the word is blended — it
/// separates "that was the last sound" from "now here's the whole word".
private let blendLeadIn: Duration = .milliseconds(600)

/// Silence *between* sounds in a sound-out, held AFTER each clip has fully
/// played (see `PhonicsAudio.playSounds`).
private let blendSoundGap: Duration = .milliseconds(50)

// MARK: - Shared pieces

/// A quick horizontal shake used for wrong answers.
private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit * 2), y: 0))
    }
}

private extension View {
    /// Wiggles whenever `trigger` changes (bump an Int to shake).
    func wiggle(on trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(.linear(duration: 0.4), value: trigger)
    }
}

/// Small white "hear it" pill that re-speaks the current word.
private struct HearButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 16, weight: .bold))
                Text("Hear it").font(Theme.rounded(14, .bold))
            }
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Capsule().fill(.white))
            .softShadow()
        }
        .buttonStyle(PressableStyle())
    }
}

/// A small tinted speaker chip (hear a candidate without picking it).
private struct SpeakerChip: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(Capsule().fill(color.opacity(0.15)))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Shared per-round feedback used by every phonics game: a cheerful "correct"
/// message with a Next button (so the child controls the pace), or a gentle
/// "try again" nudge after a wrong choice.
private struct RoundFeedback: View {
    let solved: Bool
    let showWrong: Bool
    let isLast: Bool
    let color: Color
    let onNext: () -> Void

    var body: some View {
        if solved {
            VStack(spacing: 10) {
                Text("Great job! 🎉")
                    .font(Theme.rounded(18, .black))
                    .foregroundStyle(Theme.green)
                KidButton(title: isLast ? "Finish ▶" : "Next ▶", color: color, action: onNext)
            }
            .frame(maxWidth: .infinity)
            .transition(.scale.combined(with: .opacity))
        } else if showWrong {
            Text("Not quite — listen again and try once more! 🙂")
                .font(Theme.rounded(16, .bold))
                .foregroundStyle(Theme.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Pop the Phoneme

/// Which starting *sound* does this picture make? The choices are numbered
/// sound bubbles (the letter is hidden so the decision is made by ear): a
/// speaker plays the phoneme, "Pick" answers with it.
struct PopPhonemeGame: View {
    let rounds: [PopRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var mistakes = 0
    @State private var wrong: Int?
    @State private var solved = false
    @State private var options: [String]
    @State private var shakes = 0

    init(rounds: [PopRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _options = State(initialValue: rounds[0].options.shuffled())
    }

    private var round: PopRound { rounds[index] }
    private var isLast: Bool { index + 1 >= rounds.count }
    private var correctIndex: Int? { options.firstIndex(of: round.answer) }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(round.emoji).font(.system(size: 84))
                Text(round.word)
                    .font(Theme.rounded(26, .black))
                    .foregroundStyle(Theme.ink)
                HearButton(color: color) { audio.speak(round.word) }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .kidCard()

            Text("Hear each sound, then pick the one it starts with!")
                .font(Theme.rounded(17, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(options.indices, id: \.self) { i in
                    soundOption(i)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrong != nil, isLast: isLast, color: color) {
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) {
            onProgress(index, rounds.count)
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            audio.speak(round.word)
        }
        .task(id: wrong) {
            guard wrong != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation { wrong = nil }
        }
    }

    private func soundOption(_ i: Int) -> some View {
        let isWrong = wrong == i
        let isRight = solved && correctIndex == i
        return VStack(spacing: 8) {
            Text("\(i + 1)")
                .font(Theme.rounded(34, .black))
                .foregroundStyle(color)
            SpeakerChip(color: color) {
                Task { await audio.play(options[i]) }
            }
            Button {
                pick(i)
            } label: {
                Text("Pick")
                    .font(Theme.rounded(15, .black))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(12)
        .frame(maxWidth: 120)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isWrong ? Theme.red.opacity(0.18)
                      : isRight ? Theme.green.opacity(0.2) : .white))
        .softShadow()
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func pick(_ i: Int) {
        guard wrong == nil, !solved else { return }
        if options[i] == round.answer {
            withAnimation { solved = true }
        } else {
            mistakes += 1
            withAnimation { wrong = i; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrong = nil
        options = rounds[index].options.shuffled()
    }
}

// MARK: - Build the Word

/// Build the word from letter tiles by *sound*: the child taps tiles in order;
/// each correct letter plays its phoneme; a wrong tap counts a mistake and
/// wiggles. Silent letters play nothing and land ghosted with a 🤫 — that
/// quiet is the lesson in Whisper Woods.
struct BuildWordGame: View {
    let rounds: [BuildRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    @State private var index = 0
    @State private var mistakes = 0
    @State private var solved = false
    @State private var tiles: [Character]
    @State private var used: Set<Int> = []
    @State private var wrongTile: Int?
    @State private var shakes = 0

    init(rounds: [BuildRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _tiles = State(initialValue: Array(rounds[0].word).shuffled())
    }

    private var round: BuildRound { rounds[index] }
    private var target: [Character] { Array(round.word) }
    private var isLast: Bool { index + 1 >= rounds.count }
    private var slotSize: CGFloat { compact ? 44 : 50 }
    private var tileSize: CGFloat { compact ? 48 : 56 }

    var body: some View {
        VStack(spacing: 18) {
            Text("Tap the letters in order to build the word!")
                .font(Theme.rounded(18, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Text(round.emoji).font(.system(size: 76))
                HearButton(color: color) { audio.speak(round.word) }
                HStack(spacing: compact ? 6 : 8) {
                    ForEach(target.indices, id: \.self) { i in
                        slot(i)
                    }
                }
                if round.hasSilentLetters {
                    Text("Shh 🤫 some letters in this word are quiet!")
                        .font(Theme.rounded(13, .bold))
                        .foregroundStyle(color.opacity(0.9))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .kidCard()

            HStack(spacing: compact ? 8 : 10) {
                ForEach(tiles.indices, id: \.self) { i in
                    tile(i)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrongTile != nil, isLast: isLast, color: color) {
                // Stop the completion sound-out first so it can't bleed into the
                // next round — the child chose to move on.
                audio.stop()
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) {
            onProgress(index, rounds.count)
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            audio.speak(round.word)
        }
        .task(id: wrongTile) {
            guard wrongTile != nil else { return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            withAnimation { wrongTile = nil }
        }
        // Sound out the finished word: a beat of real silence, each sound fully,
        // in order, then the word itself. Advancing mid-sound-out cancels this
        // task (solved resets) and `audio.stop()` cuts the clip.
        .task(id: solved) {
            guard solved else { return }
            try? await Task.sleep(for: blendLeadIn)
            guard !Task.isCancelled else { return }
            await audio.playSounds(round.sounds, gap: blendSoundGap)
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            audio.speak(round.word)
        }
        .onDisappear { audio.stop() }
    }

    /// One target slot; filled slots show the letter, silent letters ghosted
    /// with a tiny 🤫.
    private func slot(_ i: Int) -> some View {
        let filled = i < used.count
        let silent = round.sounds[i].isEmpty
        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(filled ? color.opacity(0.2) : Theme.ink.opacity(0.06))
                .frame(width: slotSize, height: slotSize)
            if filled {
                Text(String(target[i]))
                    .font(Theme.rounded(26, .black))
                    .foregroundStyle(silent ? color.opacity(0.35) : color)
                    .frame(width: slotSize, height: slotSize)
                if silent {
                    Text("🤫").font(.system(size: 13)).offset(x: 3, y: -5)
                }
            }
        }
    }

    private func tile(_ i: Int) -> some View {
        let isUsed = used.contains(i)
        let isWrong = wrongTile == i
        return Button {
            tap(i)
        } label: {
            Text(String(tiles[i]))
                .font(Theme.rounded(28, .black))
                .foregroundStyle(isWrong ? .white : Theme.ink)
                .frame(width: tileSize, height: tileSize)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isWrong ? Theme.red : .white))
                .softShadow()
                .opacity(isUsed ? 0.25 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(isUsed || solved)
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func tap(_ i: Int) {
        guard !used.contains(i), wrongTile == nil, !solved else { return }
        let position = used.count
        if tiles[i] == target[position] {
            used.insert(i)
            // Sound the letter as it lands — a silent letter plays nothing,
            // which is exactly the point.
            let slug = round.sounds[position]
            if !slug.isEmpty {
                Task { await audio.play(slug) }
            }
            if used.count == target.count {
                withAnimation { solved = true }
            }
        } else {
            mistakes += 1
            withAnimation { wrongTile = i; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrongTile = nil
        used = []
        tiles = Array(rounds[index].word).shuffled()
    }
}

// MARK: - Rhyme Time

/// Hear/see the word, pick which of 3 pictures rhymes.
struct RhymeGame: View {
    let rounds: [RhymeRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var mistakes = 0
    @State private var wrong: Int?
    @State private var solved = false
    @State private var order: [Int]
    @State private var shakes = 0

    init(rounds: [RhymeRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _order = State(initialValue: Array(rounds[0].options.indices).shuffled())
    }

    private var round: RhymeRound { rounds[index] }
    private var isLast: Bool { index + 1 >= rounds.count }

    var body: some View {
        VStack(spacing: 18) {
            Text("Which word rhymes?")
                .font(Theme.rounded(18, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))

            VStack(spacing: 8) {
                Text(round.emoji).font(.system(size: 72))
                Text(round.word)
                    .font(Theme.rounded(26, .black))
                    .foregroundStyle(Theme.ink)
                HearButton(color: color) { audio.speak(round.word) }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .kidCard()

            HStack(spacing: 12) {
                ForEach(order, id: \.self) { orig in
                    optionCard(orig)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrong != nil, isLast: isLast, color: color) {
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) {
            onProgress(index, rounds.count)
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            audio.speak(round.word)
        }
        .task(id: wrong) {
            guard wrong != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation { wrong = nil }
        }
    }

    private func optionCard(_ orig: Int) -> some View {
        let option = round.options[orig]
        let isWrong = wrong == orig
        let isRight = solved && orig == round.answer
        return VStack(spacing: 8) {
            Button {
                pick(orig)
            } label: {
                VStack(spacing: 8) {
                    Text(option.emoji).font(.system(size: 40))
                    Text(option.word)
                        .font(Theme.rounded(15, .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            // Hear this candidate without choosing it.
            SpeakerChip(color: color) { audio.speak(option.word) }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: 120)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isWrong ? Theme.red.opacity(0.18)
                      : isRight ? Theme.green.opacity(0.2) : .white))
        .softShadow()
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func pick(_ orig: Int) {
        guard wrong == nil, !solved else { return }
        if orig == round.answer {
            audio.speak(round.options[orig].word)
            withAnimation { solved = true }
        } else {
            mistakes += 1
            withAnimation { wrong = orig; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrong = nil
        order = Array(rounds[index].options.indices).shuffled()
    }
}

// MARK: - Listen & Find

/// The word is SPOKEN only (no picture) — tap the matching written word among
/// similar-sounding choices.
struct ListenFindGame: View {
    let rounds: [ListenRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var mistakes = 0
    @State private var wrong: Int?
    @State private var solved = false
    @State private var order: [Int]
    @State private var shakes = 0

    init(rounds: [ListenRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _order = State(initialValue: Array(rounds[0].options.indices).shuffled())
    }

    private var round: ListenRound { rounds[index] }
    private var isLast: Bool { index + 1 >= rounds.count }

    var body: some View {
        VStack(spacing: 18) {
            Text("Listen, then tap the word you hear!")
                .font(Theme.rounded(18, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            // Big "listen" card (no word shown — they must listen).
            VStack(spacing: 10) {
                Button {
                    audio.speak(round.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(color))
                        .softShadow()
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                Text("Tap to hear again")
                    .font(Theme.rounded(13, .bold))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .kidCard()

            HStack(spacing: 12) {
                ForEach(order, id: \.self) { orig in
                    optionCard(orig)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrong != nil, isLast: isLast, color: color) {
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) {
            onProgress(index, rounds.count)
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            audio.speak(round.word)
        }
        .task(id: wrong) {
            guard wrong != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation { wrong = nil }
        }
    }

    private func optionCard(_ orig: Int) -> some View {
        let word = round.options[orig]
        let isWrong = wrong == orig
        let isRight = solved && orig == round.answer
        return VStack(spacing: 8) {
            Button {
                pick(orig)
            } label: {
                Text(word)
                    .font(Theme.rounded(20, .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            // Hear this similar-sounding candidate without choosing it.
            SpeakerChip(color: color) { audio.speak(word) }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: 120)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isWrong ? Theme.red.opacity(0.18)
                      : isRight ? Theme.green.opacity(0.2) : .white))
        .softShadow()
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func pick(_ orig: Int) {
        guard wrong == nil, !solved else { return }
        if orig == round.answer {
            audio.speak(round.options[orig])
            withAnimation { solved = true }
        } else {
            mistakes += 1
            withAnimation { wrong = orig; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrong = nil
        order = Array(rounds[index].options.indices).shuffled()
    }
}

// MARK: - Sound Blender

/// Phoneme sounds play in sequence; the child blends them in their head and
/// taps the picture of the blended word. A dot per sound replays it alone;
/// "Blend it!" replays the whole sequence.
struct BlendGame: View {
    let rounds: [BlendRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var mistakes = 0
    @State private var wrong: Int?
    @State private var solved = false
    @State private var order: [Int]
    // Bumped by "Blend it!" to replay; reset each round so the first auto-play
    // gets its gentle lead-in delay.
    @State private var blendTick = 0
    @State private var shakes = 0

    init(rounds: [BlendRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _order = State(initialValue: Array(rounds[0].options.indices).shuffled())
    }

    private var round: BlendRound { rounds[index] }
    private var isLast: Bool { index + 1 >= rounds.count }
    private var sounds: [String] { round.sounds.filter { !$0.isEmpty } }

    /// Identity for the blend playback task: changes on a new round or a replay,
    /// cancelling (and cutting) any stale blend.
    private struct BlendKey: Equatable { let index: Int; let tick: Int }

    var body: some View {
        VStack(spacing: 18) {
            Text("Blend the sounds, then tap the picture!")
                .font(Theme.rounded(18, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            // Tap a dot to hear that sound alone, or "Blend it" to hear them
            // together.
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ForEach(sounds.indices, id: \.self) { i in
                        Button {
                            Task { await audio.play(sounds[i]) }
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(color)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(color.opacity(0.15)))
                                .softShadow()
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                    }
                }
                KidButton(title: "Blend it! 🔊", color: color) { blendTick += 1 }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .kidCard()

            HStack(spacing: 12) {
                ForEach(order, id: \.self) { orig in
                    optionCard(orig)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrong != nil, isLast: isLast, color: color) {
                audio.stop()
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) { onProgress(index, rounds.count) }
        // Play the sounds in order on entry and on each "Blend it!". Keying on
        // index and tick cancels a stale blend — and cuts its audio — if the
        // child advances or replays mid-playback.
        .task(id: BlendKey(index: index, tick: blendTick)) {
            try? await Task.sleep(for: .milliseconds(blendTick == 0 ? 350 : 0))
            guard !Task.isCancelled else { return }
            await audio.playSounds(sounds, gap: blendSoundGap)
        }
        .task(id: wrong) {
            guard wrong != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation { wrong = nil }
        }
        .onDisappear { audio.stop() }
    }

    private func optionCard(_ orig: Int) -> some View {
        let option = round.options[orig]
        let isWrong = wrong == orig
        let isRight = solved && orig == round.answer
        return Button {
            pick(orig)
        } label: {
            VStack(spacing: 6) {
                Text(option.emoji).font(.system(size: 44))
                Text(option.word)
                    .font(Theme.rounded(16, .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isWrong ? Theme.red.opacity(0.18)
                          : isRight ? Theme.green.opacity(0.2) : .white))
            .softShadow()
        }
        .buttonStyle(PressableStyle())
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func pick(_ orig: Int) {
        guard wrong == nil, !solved else { return }
        if orig == round.answer {
            audio.speak(round.options[orig].word)
            withAnimation { solved = true }
        } else {
            mistakes += 1
            withAnimation { wrong = orig; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrong = nil
        blendTick = 0
        order = Array(rounds[index].options.indices).shuffled()
    }
}

// MARK: - Buddy Sounds (digraphs)

/// The bundled clip for a two-letter team.
private func slugForTeam(_ team: String) -> String {
    switch team {
    case "sh": "c_sh"
    case "ch": "c_ch"
    case "th": "c_th_unvoiced"
    case "ng": "c_ng"
    default: ""
    }
}

/// Hear a digraph sound, pick the letter team (sh/ch/th/ng) that spells it.
/// On a win the example emoji/word reinforce the mapping.
struct DigraphGame: View {
    let rounds: [DigraphRound]
    let color: Color
    let audio: PhonicsAudio
    let onProgress: (Int, Int) -> Void
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var mistakes = 0
    @State private var wrong: Int?
    @State private var solved = false
    @State private var order: [Int]
    @State private var shakes = 0

    init(rounds: [DigraphRound], color: Color, audio: PhonicsAudio,
         onProgress: @escaping (Int, Int) -> Void, onFinish: @escaping (Int) -> Void) {
        self.rounds = rounds
        self.color = color
        self.audio = audio
        self.onProgress = onProgress
        self.onFinish = onFinish
        _order = State(initialValue: Array(rounds[0].teams.indices).shuffled())
    }

    private var round: DigraphRound { rounds[index] }
    private var isLast: Bool { index + 1 >= rounds.count }

    var body: some View {
        VStack(spacing: 18) {
            Text("Which two letters make this sound?")
                .font(Theme.rounded(18, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            // Big listen button for the target digraph sound (no word — the
            // child must map the sound to its two-letter spelling).
            VStack(spacing: 10) {
                Button {
                    Task { await audio.play(round.sound) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(color))
                        .softShadow()
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                Text("Tap to hear again")
                    .font(Theme.rounded(13, .bold))
                    .foregroundStyle(Theme.ink.opacity(0.5))
                // On a win, reinforce: the two letters → a word that uses them.
                if solved {
                    HStack(spacing: 8) {
                        Text(round.teams[round.answer])
                            .font(Theme.rounded(30, .black))
                            .foregroundStyle(color)
                        Text("→")
                            .font(Theme.rounded(22, .black))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        Text(round.exampleEmoji).font(.system(size: 30))
                        Text(round.exampleWord)
                            .font(Theme.rounded(20, .black))
                            .foregroundStyle(Theme.ink)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .kidCard()

            // Letter-team choices; a small speaker on each lets the child compare.
            HStack(spacing: 12) {
                ForEach(order, id: \.self) { orig in
                    teamCard(orig)
                }
            }
            .frame(maxWidth: .infinity)

            RoundFeedback(solved: solved, showWrong: wrong != nil, isLast: isLast, color: color) {
                if isLast { onFinish(mistakes) } else { advance() }
            }
        }
        .task(id: index) {
            onProgress(index, rounds.count)
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await audio.play(round.sound)
        }
        .task(id: wrong) {
            guard wrong != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation { wrong = nil }
        }
    }

    private func teamCard(_ orig: Int) -> some View {
        let team = round.teams[orig]
        let isWrong = wrong == orig
        let isRight = solved && orig == round.answer
        return VStack(spacing: 8) {
            Button {
                pick(orig)
            } label: {
                Text(team)
                    .font(Theme.rounded(32, .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            // Hear this team's sound without choosing it.
            SpeakerChip(color: color) {
                Task { await audio.play(slugForTeam(team)) }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: 110)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isWrong ? Theme.red.opacity(0.18)
                      : isRight ? Theme.green.opacity(0.2) : .white))
        .softShadow()
        .wiggle(on: isWrong ? shakes : 0)
    }

    private func pick(_ orig: Int) {
        guard wrong == nil, !solved else { return }
        if orig == round.answer {
            audio.speak(round.exampleWord)
            withAnimation { solved = true }
        } else {
            mistakes += 1
            withAnimation { wrong = orig; shakes += 1 }
        }
    }

    private func advance() {
        index += 1
        solved = false
        wrong = nil
        order = Array(rounds[index].teams.indices).shuffled()
    }
}
