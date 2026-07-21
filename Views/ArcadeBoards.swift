import SwiftUI

/// SwiftUI board renderers for the eight offline Brain Arcade games — ports of
/// the Android `CardBoards.kt` composables. Each board reads its `@Observable`
/// engine and drives it directly through taps.

// MARK: - engine conformance

/// Common surface the generic player container needs from every game engine.
@MainActor protocol ArcadeEngine: AnyObject {
    var isOver: Bool { get }
    var lost: Bool { get }
}

extension MemoryEngine: ArcadeEngine {}
extension TowerTumbleEngine: ArcadeEngine {}
extension NumberHuntEngine: ArcadeEngine {}
extension BeatDieEngine: ArcadeEngine {}
extension MakeTenEngine: ArcadeEngine {}
extension AnimalCountEngine: ArcadeEngine {}
extension OddOneOutEngine: ArcadeEngine {}
extension AlphabetLockEngine: ArcadeEngine {}

// MARK: - shared bits

/// A thin horizontal countdown bar that fills `fraction` (0...1) in `color`.
struct TimerBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.1))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}

/// A single elongated playing-card chip with a large centre value.
struct PlayingCardChip: View {
    let value: Int
    let selected: Bool
    let enabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(Theme.rounded(24, .black))
                .foregroundStyle(selected ? .white : Theme.ink)
                .frame(width: 48, height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Theme.pink : .white))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? Theme.pink : Theme.ink.opacity(0.12), lineWidth: 1.5))
                .softShadow()
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/// A wrapping row of selectable hand cards (by index, so duplicate values work).
struct HandRow: View {
    let hand: [Int]
    let selected: Set<Int>
    let enabled: Bool
    let onTap: (Int) -> Void

    var body: some View {
        if hand.isEmpty {
            Text("(no cards)").font(Theme.rounded(14, .medium)).foregroundStyle(Theme.ink.opacity(0.4))
        } else {
            VStack(spacing: 10) {
                ForEach(Array(stride(from: 0, to: hand.count, by: 6)), id: \.self) { start in
                    HStack(spacing: 8) {
                        ForEach(start..<min(start + 6, hand.count), id: \.self) { idx in
                            PlayingCardChip(value: hand[idx], selected: selected.contains(idx),
                                            enabled: enabled) { onTap(idx) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private func toggle(_ set: inout Set<Int>, _ idx: Int, max: Int) {
    if set.contains(idx) { set.remove(idx) }
    else if set.count < max { set.insert(idx) }
}

private func sectionLabel(_ text: String) -> some View {
    Text(text).font(Theme.rounded(14, .bold)).foregroundStyle(Theme.ink.opacity(0.6))
        .frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: - Memory Match

struct MemoryBoard: View {
    let engine: MemoryEngine
    private var cols: Int { let t = engine.cards.count; return t <= 16 ? 4 : (t <= 20 ? 5 : 6) }

    var body: some View {
        VStack(spacing: 10) {
            sectionLabel("Pairs found: \(engine.pairsFound)/\(engine.pairsTotal)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cols), spacing: 8) {
                ForEach(engine.cards) { card in
                    let up = engine.isUp(card)
                    let matched = engine.matched.contains(card.id)
                    Button { engine.flip(card.id) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(matched ? Theme.green.opacity(0.2) : (up ? Color.white : Theme.purple))
                            if up {
                                Text(card.label)
                                    .font(card.face == .emoji ? .system(size: 30) : Theme.rounded(15, .bold))
                                    .foregroundStyle(matched ? Theme.green : Theme.ink)
                                    .minimumScaleFactor(0.5).multilineTextAlignment(.center).lineLimit(2)
                            } else {
                                Text("?").font(Theme.rounded(26, .black)).foregroundStyle(.white)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(engine.mismatch || up || engine.flipped.count >= 2)
                }
            }
        }
        .task(id: engine.mismatch) {
            if engine.mismatch {
                try? await Task.sleep(for: .milliseconds(1100))
                engine.clearMismatch()
            }
        }
    }
}

// MARK: - Tower Tumble

struct TowerTumbleBoard: View {
    let engine: TowerTumbleEngine
    @State private var selected: Int?

    var body: some View {
        VStack(spacing: 14) {
            sectionLabel("Four piles — play higher, or a 10 to clear")
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    let top = engine.piles[i]
                    let playable = selected != nil
                    Button {
                        if let card = selected { engine.play(pile: i, card: card); selected = nil }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(top == 0 ? Theme.blue.opacity(0.08) : Color.white)
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(playable ? Theme.blue : Theme.ink.opacity(0.12),
                                        lineWidth: playable ? 2.5 : 1.5)
                            if top == 0 {
                                Text("any").font(Theme.rounded(13, .bold)).foregroundStyle(Theme.blue.opacity(0.6))
                            } else {
                                Text("\(top)").font(Theme.rounded(30, .black)).foregroundStyle(Theme.ink)
                            }
                        }
                        .aspectRatio(0.7, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!playable)
                }
            }
            sectionLabel("Your cards")
            HandRow(hand: engine.hand, selected: selected.map { v in Set(engine.hand.firstIndex(of: v).map { [$0] } ?? []) } ?? [],
                    enabled: true) { idx in
                let v = engine.hand[idx]
                selected = (selected == v) ? nil : v
            }
            if let err = engine.error { ErrorChip(err) }
            KidButton(title: "Pass", color: engine.canPlay ? Theme.ink.opacity(0.3) : Theme.orange) {
                engine.pass(); selected = nil
            }
            .disabled(engine.canPlay)
        }
    }
}

// MARK: - Number Hunt

struct NumberHuntBoard: View {
    let engine: NumberHuntEngine
    @State private var picked: Set<Int> = []

    var body: some View {
        VStack(spacing: 14) {
            TargetChip(label: "🎯 Target", value: engine.target, color: Theme.blue)
            Text("Pick 1 card = target, or 2 that add/subtract to it")
                .font(Theme.rounded(13, .medium)).foregroundStyle(Theme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
            HandRow(hand: engine.hand, selected: picked, enabled: true) { toggle(&picked, $0, max: 2) }
            if let err = engine.error { ErrorChip(err) }
            HStack(spacing: 10) {
                KidButton(title: "Discard", color: picked.isEmpty ? Theme.ink.opacity(0.3) : Theme.green) {
                    engine.discard(picked.sorted().map { engine.hand[$0] }); picked.removeAll()
                }
                .disabled(picked.isEmpty)
                KidButton(title: "Draw", color: Theme.orange) { engine.drawCard(); picked.removeAll() }
            }
        }
        .onChange(of: engine.hand) { _, _ in picked.removeAll() }
        .onChange(of: engine.target) { _, _ in picked.removeAll() }
    }
}

// MARK: - Beat the Die

struct BeatDieBoard: View {
    let engine: BeatDieEngine
    @State private var picked: Set<Int> = []

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.green.opacity(0.15))
                Text(engine.die.map { "🎲 \($0)" } ?? "🎲")
                    .font(Theme.rounded(24, .black)).foregroundStyle(Theme.green)
            }
            .frame(width: 80, height: 72)

            if engine.die == nil {
                KidButton(title: "Roll the die", color: Theme.green) { engine.roll() }
            } else {
                Text("Discard 1–2 cards adding up to at least \(engine.die!)")
                    .font(Theme.rounded(13, .medium)).foregroundStyle(Theme.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                HandRow(hand: engine.hand, selected: picked, enabled: true) { toggle(&picked, $0, max: 2) }
                HStack(spacing: 10) {
                    KidButton(title: "Discard", color: picked.isEmpty ? Theme.ink.opacity(0.3) : Theme.green) {
                        engine.discard(picked.sorted().map { engine.hand[$0] }); picked.removeAll()
                    }
                    .disabled(picked.isEmpty)
                    KidButton(title: "Draw", color: Theme.orange) { engine.drawCard(); picked.removeAll() }
                }
            }
            if let err = engine.error { ErrorChip(err) }
        }
        .onChange(of: engine.hand) { _, _ in picked.removeAll() }
        .onChange(of: engine.die) { _, _ in picked.removeAll() }
    }
}

// MARK: - Make Ten

struct MakeTenBoard: View {
    let engine: MakeTenEngine
    @State private var selected: [Int] = []
    @State private var remaining: Double = 0

    var body: some View {
        let urgent = remaining <= 2
        let timerColor = urgent ? Theme.red : Theme.teal
        VStack(spacing: 10) {
            HStack {
                sectionLabel("Round \(engine.round)/\(engine.goal)")
                Text("⏱ \(Int(remaining.rounded(.up)))s")
                    .font(Theme.rounded(16, .black)).foregroundStyle(timerColor)
            }
            TimerBar(fraction: remaining / max(engine.roundSeconds, 0.001), color: timerColor)
            sectionLabel("Tap two cards that add to 10")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(engine.cards) { card in
                    let on = selected.contains(card.id)
                    Button { tap(card.id) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Theme.teal : Color.white)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(on ? Theme.teal : Theme.ink.opacity(0.12), lineWidth: on ? 2.5 : 1.5)
                            Text("\(card.value)").font(Theme.rounded(22, .black))
                                .foregroundStyle(on ? .white : Theme.ink)
                        }
                        .aspectRatio(0.72, contentMode: .fit)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .task(id: engine.round) {
            remaining = engine.roundSeconds
            let deadline = Date().addingTimeInterval(engine.roundSeconds)
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                remaining = max(0, left)
                if left <= 0 { engine.timeout(); break }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func tap(_ id: Int) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i); return }
        if selected.count >= 2 { return }
        selected.append(id)
        if selected.count == 2 { engine.clear(selected); selected.removeAll() }
    }
}

// MARK: - Animal Count

struct AnimalCountBoard: View {
    let engine: AnimalCountEngine
    @State private var spinning = false
    @State private var spinIdx = 0
    @State private var ready = false
    @State private var remaining: Double = 0

    var body: some View {
        let urgent = remaining <= 2
        let timerColor = urgent ? Theme.red : Theme.orange
        VStack(spacing: 12) {
            sectionLabel("Round \(engine.round)/\(engine.roundsTotal) · Pick \(engine.subround)/\(engine.subroundsTotal)")

            HStack(spacing: 8) {
                ForEach(Array(engine.wheel.enumerated()), id: \.offset) { i, a in
                    let on = i == spinIdx
                    Text(a).font(.system(size: on ? 30 : 22))
                        .frame(width: on ? 56 : 44, height: on ? 56 : 44)
                        .background(RoundedRectangle(cornerRadius: 14).fill(on ? Theme.orange.opacity(0.22) : Theme.ink.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.orange : .clear, lineWidth: 2.5))
                }
            }
            .frame(height: 64)

            if spinning {
                Text("Choosing an animal…").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink.opacity(0.5))
            } else if !ready {
                VStack(spacing: 12) {
                    Text("🏁").font(.system(size: 48))
                    Text("Final Round!").font(Theme.rounded(24, .black)).foregroundStyle(Theme.ink)
                    Text("Just one animal left — \(engine.targetAnimal). Get this card right to win!")
                        .font(Theme.rounded(15, .medium)).foregroundStyle(Theme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                    KidButton(title: "I'm ready! ▶", color: Theme.orange) { ready = true }
                }
                .padding(24).frame(maxWidth: .infinity).kidCard()
            } else {
                HStack(spacing: 8) {
                    Text("Find the card with").font(Theme.rounded(15, .medium)).foregroundStyle(Theme.ink.opacity(0.6))
                    Text("\(engine.targetCount) \(engine.targetAnimal)")
                        .font(Theme.rounded(20, .black)).foregroundStyle(Theme.orange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.orange.opacity(0.18)))
                }
                TimerBar(fraction: remaining / max(engine.roundSeconds, 0.001), color: timerColor)
                Text("⏱ \(Int(remaining.rounded(.up)))s" + (engine.wrongPicks.isEmpty ? "" : "   ❌ no more chances — choose carefully!"))
                    .font(Theme.rounded(14, .bold))
                    .foregroundStyle(urgent || !engine.wrongPicks.isEmpty ? Theme.red : Theme.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                emojiCardGrid(engine.cards.map { ($0.id, $0.counts.flatMap { a, n in Array(repeating: a, count: n) }) },
                              wrong: Set(engine.wrongPicks), shuffleSeeded: true) { engine.pick($0) }
            }
        }
        .task(id: engine.round) { await runSpin() }
        .task(id: TimerKey(round: engine.round, sub: engine.subround, spinning: spinning, ready: ready)) {
            guard !spinning, ready else { return }
            remaining = engine.roundSeconds
            let deadline = Date().addingTimeInterval(engine.roundSeconds)
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                remaining = max(0, left)
                if left <= 0 { engine.timeout(); break }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private struct TimerKey: Equatable { let round: Int; let sub: Int; let spinning: Bool; let ready: Bool }

    private func runSpin() async {
        let targetIdx = max(0, engine.wheel.firstIndex(of: engine.targetAnimal) ?? 0)
        if engine.lastRound || engine.wheel.count <= 1 {
            spinIdx = targetIdx; spinning = false; ready = false; return
        }
        spinning = true; ready = true
        let n = engine.wheel.count
        var d: UInt64 = 55
        for s in 0...(n * 3 + targetIdx) {
            spinIdx = s % n
            try? await Task.sleep(for: .milliseconds(Int(d)))
            d += 7
        }
        spinIdx = targetIdx
        spinning = false
    }
}

// MARK: - Odd One Out

struct OddOneOutBoard: View {
    let engine: OddOneOutEngine
    @State private var remaining: Double = 0

    var body: some View {
        let urgent = remaining <= 2
        let timerColor = urgent ? Theme.red : Theme.purple
        VStack(spacing: 12) {
            sectionLabel("Round \(engine.round)/\(engine.roundsTotal) · Pick \(engine.subround)/\(engine.subroundsTotal)")
            Text("Tap the card that's different")
                .font(Theme.rounded(17, .black)).foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
            TimerBar(fraction: remaining / max(engine.roundSeconds, 0.001), color: timerColor)
            Text("⏱ \(Int(remaining.rounded(.up)))s" + (engine.wrongPicks.isEmpty ? "" : "   ❌ one mistake — look closely!"))
                .font(Theme.rounded(14, .bold))
                .foregroundStyle(urgent || !engine.wrongPicks.isEmpty ? Theme.red : Theme.ink.opacity(0.6))
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            emojiCardGrid(engine.cards.map { ($0.id, $0.counts.flatMap { a, n in Array(repeating: a, count: n) }) },
                          wrong: Set(engine.wrongPicks), shuffleSeeded: false) { engine.pick($0) }
        }
        .task(id: engine.round * 100 + engine.subround) {
            remaining = engine.roundSeconds
            let deadline = Date().addingTimeInterval(engine.roundSeconds)
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                remaining = max(0, left)
                if left <= 0 { engine.timeout(); break }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

/// Shared 2-up grid of emoji "spot" cards used by Animal Count and Odd One Out.
@MainActor
private func emojiCardGrid(_ cards: [(id: Int, emojis: [String])], wrong: Set<Int>,
                           shuffleSeeded: Bool, onTap: @escaping (Int) -> Void) -> some View {
    VStack(spacing: 10) {
        ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { row in
            HStack(spacing: 10) {
                ForEach(row..<min(row + 2, cards.count), id: \.self) { i in
                    let card = cards[i]
                    let isWrong = wrong.contains(card.id)
                    let shown = shuffleSeeded ? seededShuffle(card.emojis, seed: UInt64(card.id)) : card.emojis
                    Button { onTap(card.id) } label: {
                        Text(shown.isEmpty ? "—" : shown.joined(separator: " "))
                            .font(.system(size: 22))
                            .foregroundStyle(shown.isEmpty ? Theme.ink.opacity(0.3) : Theme.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(isWrong ? Theme.red.opacity(0.12) : Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isWrong ? Theme.red : Theme.ink.opacity(0.12), lineWidth: isWrong ? 2 : 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isWrong)
                }
                if min(row + 2, cards.count) - row == 1 { Spacer() }
            }
        }
    }
}

/// Tiny deterministic RNG so each spot-card's emoji scatter stays put across redraws.
private func seededShuffle(_ arr: [String], seed: UInt64) -> [String] {
    var rng = SeededRNG(seed: seed)
    return arr.shuffled(using: &rng)
}

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Alphabet Lock

struct AlphabetLockBoard: View {
    let engine: AlphabetLockEngine

    var body: some View {
        VStack(spacing: 14) {
            Text("Flip the letters in ABC order")
                .font(Theme.rounded(17, .black)).foregroundStyle(Theme.ink).frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach(Array(engine.order.enumerated()), id: \.offset) { i, l in
                    let done = i < engine.progress
                    let next = i == engine.progress && !engine.wrong
                    Text(l).font(Theme.rounded(14, .black))
                        .foregroundStyle(done ? .white : (next ? Theme.blue : Theme.ink.opacity(0.4)))
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(done ? Theme.green : (next ? Theme.blue.opacity(0.15) : Theme.ink.opacity(0.06))))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(next ? Theme.blue : .clear, lineWidth: 2))
                }
            }
            ForEach(Array(stride(from: 0, to: engine.cards.count, by: 3)), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row..<min(row + 3, engine.cards.count), id: \.self) { i in
                        let c = engine.cards[i]
                        let up = engine.isFaceUp(c)
                        let isWrong = c.id == engine.wrongCard
                        let correct = up && !isWrong
                        Button { engine.flip(c.id) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isWrong ? Theme.red.opacity(0.15) : (up ? Color.white : Theme.blue))
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(correct ? Theme.green : .clear, lineWidth: 2.5)
                                if up {
                                    Text(c.letter).font(Theme.rounded(34, .black)).foregroundStyle(isWrong ? Theme.red : Theme.green)
                                } else {
                                    Text("?").font(Theme.rounded(30, .black)).foregroundStyle(.white)
                                }
                            }
                            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(engine.wrong || up)
                    }
                }
            }
            sectionLabel("\(engine.progress)/\(engine.total) in order")
        }
        .task(id: engine.wrong) {
            if engine.wrong {
                try? await Task.sleep(for: .milliseconds(900))
                engine.hide()
            }
        }
    }
}

// MARK: - small shared views

struct TargetChip: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(Theme.rounded(12, .medium)).foregroundStyle(Theme.ink.opacity(0.5))
            Text("\(value)").font(Theme.rounded(26, .black)).foregroundStyle(color)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.15)))
        }
    }
}

struct ErrorChip: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.rounded(14, .medium)).foregroundStyle(Theme.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.red.opacity(0.1)))
    }
}
