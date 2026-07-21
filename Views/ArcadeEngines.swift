import SwiftUI
import Observation

/// On-device solo engines — Swift ports of the Android `LocalSolo.kt` card
/// games (Memory Match, Tower Tumble, Number Hunt, Beat the Die, Make Ten,
/// Animal Count, Odd One Out, Alphabet Lock). Each is a small `@Observable`
/// state machine the matching board view reads and drives directly. Everything
/// runs fully offline — no network, no sign-in, no data collection.

// MARK: - shared helpers

/// 40-card deck of values: 1...10, four of each, shuffled.
@MainActor func deckValues() -> [Int] {
    var out: [Int] = []
    for _ in 0..<4 { out.append(contentsOf: 1...10) }
    return out.shuffled()
}

/// Removes one occurrence of each value in `cards` from `hand`. Returns false
/// (leaving `hand` untouched) if any value isn't present.
@discardableResult
@MainActor func removeFromHand(_ hand: inout [Int], _ cards: [Int]) -> Bool {
    var copy = hand
    for c in cards {
        guard let i = copy.firstIndex(of: c) else { return false }
        copy.remove(at: i)
    }
    hand = copy
    return true
}

// MARK: - Memory Match

@Observable
@MainActor
final class MemoryEngine {
    enum Face { case word, emoji }
    struct Card: Identifiable { let id: Int; let concept: Int; let face: Face; let label: String }

    private static let concepts: [(String, String)] = [
        ("plant", "🌱"), ("star", "⭐"), ("rocket", "🚀"), ("robot", "🤖"),
        ("apple", "🍎"), ("cat", "🐱"), ("fish", "🐟"), ("sun", "☀️"),
        ("moon", "🌙"), ("tree", "🌳"), ("car", "🚗"), ("ball", "⚽"),
        ("cake", "🍰"), ("dog", "🐶"), ("frog", "🐸"), ("boat", "⛵"),
    ]

    private(set) var cards: [Card]
    private(set) var matched = Set<Int>()
    private(set) var flipped: [Int] = []
    private(set) var mismatch = false
    private(set) var flips = 0
    let pairsTotal: Int

    init(pairs: Int) {
        let p = min(max(pairs, 4), Self.concepts.count)
        let chosen = Self.concepts.shuffled().prefix(p)
        var list: [Card] = []
        var id = 0
        for (ci, c) in chosen.enumerated() {
            list.append(Card(id: id, concept: ci, face: .word, label: c.0)); id += 1
            list.append(Card(id: id, concept: ci, face: .emoji, label: c.1)); id += 1
        }
        cards = list.shuffled()
        pairsTotal = p
    }

    var pairsFound: Int { matched.count / 2 }
    var isOver: Bool { matched.count >= pairsTotal * 2 }
    var lost: Bool { false }

    func isUp(_ c: Card) -> Bool { matched.contains(c.id) || flipped.contains(c.id) }

    func clearMismatch() { flipped.removeAll(); mismatch = false }

    func flip(_ id: Int) {
        if mismatch { clearMismatch() }
        guard cards.contains(where: { $0.id == id }) else { return }
        if matched.contains(id) || flipped.contains(id) || flipped.count >= 2 { return }
        flipped.append(id); flips += 1
        if flipped.count == 2 {
            let a = cards.first { $0.id == flipped[0] }!
            let b = cards.first { $0.id == flipped[1] }!
            if a.concept == b.concept {
                matched.insert(a.id); matched.insert(b.id); flipped.removeAll()
            } else {
                mismatch = true
            }
        }
    }
}

// MARK: - Tower Tumble

@Observable
@MainActor
final class TowerTumbleEngine {
    private(set) var piles: [Int]
    private(set) var hand: [Int]
    private(set) var done = false
    var error: String?

    init() {
        let deck = deckValues()
        piles = (0..<4).map { let v = deck[$0]; return v == 10 ? 0 : v }
        hand = Array(deck.dropFirst(4)).sorted()
    }

    var canPlay: Bool { hand.contains { c in c == 10 || piles.contains { c > $0 } } }
    var isOver: Bool { done }
    var lost: Bool { false }

    func play(pile: Int, card: Int) {
        guard pile >= 0, pile < 4, hand.contains(card) else { return }
        let top = piles[pile]
        guard card == 10 || card > top else {
            error = "Play a card higher than \(top), or a 10 to clear."
            return
        }
        removeFromHand(&hand, [card])
        piles[pile] = card == 10 ? 0 : card
        error = nil
        if hand.isEmpty { done = true }
    }

    func pass() {
        if canPlay { error = "You have a move — play a card!"; return }
        piles = [0, 0, 0, 0]
        error = nil
    }
}

// MARK: - Number Hunt

@Observable
@MainActor
final class NumberHuntEngine {
    private(set) var hand: [Int] = []
    private(set) var target: Int
    private var draw: [Int]
    private(set) var discardTop: Int
    private var discardPile: [Int]
    private(set) var done = false
    private var lowWater: Int
    private var sinceProgress = 0
    private var dead = false
    var error: String?

    init() {
        let deck = deckValues()
        let top = deck[5]
        hand = Array(deck[0..<5]).sorted()
        discardTop = top
        discardPile = [top]
        draw = Array(deck[6...])
        target = 2 + Int.random(in: 0..<8)
        lowWater = 5
    }

    var drawCount: Int { draw.count }
    var isOver: Bool { dead || done }
    var lost: Bool { false }

    private func makesTarget(_ cards: [Int], _ t: Int) -> Bool {
        switch cards.count {
        case 1: return cards[0] == t
        case 2: return cards[0] + cards[1] == t || abs(cards[0] - cards[1]) == t
        default: return false
        }
    }

    private func canDiscard(_ h: [Int], _ t: Int) -> Bool {
        if h.contains(t) { return true }
        for i in h.indices { for j in (i + 1)..<h.count where makesTarget([h[i], h[j]], t) { return true } }
        return false
    }

    private func achievableForPlayer() -> [Int] { (2...9).filter { canDiscard(hand, $0) } }

    private func relief() {
        if done { return }
        let total = hand.count
        if total < lowWater { lowWater = total; sinceProgress = 0; return }
        sinceProgress += 1
        if sinceProgress < 4 { return }
        let forNext = achievableForPlayer()
        let fresh = forNext.filter { $0 != target }
        if let f = fresh.randomElement() { target = f }
        else if let first = forNext.first { target = first }
        else { dead = true }
        sinceProgress = 0
    }

    func discard(_ cards: [Int]) {
        guard cards.count >= 1, cards.count <= 2 else { error = "Pick one or two cards."; return }
        guard makesTarget(cards, target) else {
            error = "Those don't make \(target). Try one card = \(target), or two that add/subtract to it."
            return
        }
        guard removeFromHand(&hand, cards) else { error = "You don't have those cards."; return }
        discardPile.append(contentsOf: cards)
        discardTop = cards.last!
        error = nil
        if hand.isEmpty { done = true }
        relief()
    }

    func drawCard() {
        if draw.isEmpty {
            let top = discardPile.popLast()
            draw = discardPile.shuffled()
            discardPile.removeAll()
            if let top { discardPile.append(top); discardTop = top }
        }
        if !draw.isEmpty { hand.append(draw.removeFirst()); hand.sort() }
        error = nil
        relief()
    }
}

// MARK: - Beat the Die

@Observable
@MainActor
final class BeatDieEngine {
    private(set) var hand: [Int] = []
    private var draw: [Int] = []
    private(set) var die: Int?
    private(set) var done = false
    var error: String?

    init() {
        for v in 1...4 { for _ in 0..<3 { hand.append(v) } }
        var pool: [Int] = []
        for v in 1...4 { for _ in 0..<10 { pool.append(v) } }
        draw = pool.shuffled()
        hand.sort()
    }

    var drawCount: Int { draw.count }
    var isOver: Bool { done }
    var lost: Bool { false }

    func canBeat(_ h: [Int], _ d: Int) -> Bool {
        if h.contains(where: { $0 >= d }) { return true }
        if h.count < 2 { return false }
        let top2 = h.sorted(by: >).prefix(2)
        return top2.reduce(0, +) >= d
    }

    var canBeatNow: Bool { die.map { canBeat(hand, $0) } ?? true }

    func roll() {
        if die != nil { error = "You already rolled — now discard or draw."; return }
        die = 1 + Int.random(in: 0..<6)
        error = nil
    }

    func discard(_ cards: [Int]) {
        guard let d = die else { error = "Roll the die first."; return }
        guard cards.count >= 1, cards.count <= 2 else { error = "Pick one or two cards."; return }
        let sum = cards.reduce(0, +)
        guard sum >= d else { error = "That only makes \(sum) — you need to beat \(d)."; return }
        guard removeFromHand(&hand, cards) else { error = "You don't have those cards."; return }
        error = nil
        if hand.isEmpty { done = true }
        die = nil
    }

    func drawCard() {
        guard let d = die else { error = "Roll the die first."; return }
        if canBeat(hand, d) { error = "You can beat the die — discard instead!"; return }
        if !draw.isEmpty { hand.append(draw.removeFirst()); hand.sort() }
        error = nil
        die = nil
    }
}

// MARK: - Make Ten

@Observable
@MainActor
final class MakeTenEngine {
    struct Card: Identifiable { let id: Int; let value: Int }

    private let bonds = [(1, 9), (2, 8), (3, 7), (4, 6), (5, 5)]
    let goal = 12
    private(set) var cards: [Card] = []
    private(set) var done = false
    private(set) var timedOut = false
    var error: String?

    private let startMs: Double = 8_000
    private let stepMs: Double = 400
    private let floorMs: Double = 3_000

    init() {
        var id = 0
        for _ in 0..<goal {
            let (a, b) = bonds.randomElement()!
            cards.append(Card(id: id, value: a)); id += 1
            cards.append(Card(id: id, value: b)); id += 1
        }
        cards.shuffle()
    }

    var cleared: Int { goal - cards.count / 2 }
    var round: Int { cleared + 1 }
    /// Per-round countdown budget in seconds (tightens as the board clears).
    var roundSeconds: Double { max(startMs - Double(round - 1) * stepMs, floorMs) / 1000 }

    var isOver: Bool { done || timedOut }
    var lost: Bool { timedOut }

    func clear(_ ids: [Int]) {
        guard ids.count == 2, ids[0] != ids[1] else { error = "Pick two different cards."; return }
        guard let a = cards.first(where: { $0.id == ids[0] }),
              let b = cards.first(where: { $0.id == ids[1] }) else { error = "No such card."; return }
        guard a.value + b.value == 10 else {
            error = "\(a.value) + \(b.value) = \(a.value + b.value), not 10."
            return
        }
        cards.removeAll { $0.id == a.id || $0.id == b.id }
        error = nil
        if cards.isEmpty { done = true }
    }

    func timeout() { timedOut = true }
}

// MARK: - Animal Count

@Observable
@MainActor
final class AnimalCountEngine {
    struct Card: Identifiable { let id: Int; let counts: [String: Int] }

    private let pool = ["🐶", "🐱", "🐰", "🦊", "🐻"]
    private(set) var wheel: [String]
    let roundsTotal = 5
    let subroundsTotal = 3
    private let baseMs: Double = 6_000
    private let subStepMs: Double = 1_500
    private let floorMs: Double = 1_500

    private(set) var round = 1
    private(set) var subround = 1
    private(set) var done = false
    private(set) var failed = false

    private(set) var targetAnimal = ""
    private(set) var targetCount = 0
    private(set) var cards: [Card] = []
    private(set) var wrongPicks: [Int] = []
    private var nextId = 0

    init() {
        wheel = pool
        spin(); deal()
    }

    var lastRound: Bool { wheel.count <= 1 }
    var roundSeconds: Double { max(baseMs - Double(subround - 1) * subStepMs, floorMs) / 1000 }
    var isOver: Bool { done || failed }
    var lost: Bool { failed }

    private func spin() {
        targetAnimal = wheel.randomElement()!
        targetCount = Int.random(in: 0..<3)
    }

    private func deal() {
        wrongPicks.removeAll()
        let answer = Int.random(in: 0..<5)
        cards = (0..<5).map { i in
            var counts: [String: Int] = [:]
            for a in pool {
                if a != targetAnimal { counts[a] = Int.random(in: 0..<3) }
                else if i == answer { counts[a] = targetCount }
                else { counts[a] = (0...2).filter { $0 != targetCount }.randomElement()! }
            }
            let c = Card(id: nextId, counts: counts); nextId += 1; return c
        }
    }

    func pick(_ id: Int) {
        guard let card = cards.first(where: { $0.id == id }) else { return }
        if wrongPicks.contains(id) { return }
        if (card.counts[targetAnimal] ?? 0) == targetCount { advance() }
        else {
            wrongPicks.append(id)
            if wrongPicks.count >= 2 { failed = true }
        }
    }

    func timeout() { failed = true }

    private func advance() {
        if subround < subroundsTotal { subround += 1; deal(); return }
        if round >= roundsTotal { done = true; return }
        wheel.removeAll { $0 == targetAnimal }
        round += 1; subround = 1
        spin(); deal()
    }
}

// MARK: - Odd One Out

@Observable
@MainActor
final class OddOneOutEngine {
    struct Card: Identifiable { let id: Int; let counts: [(String, Int)] }

    private let pool = ["🐶", "🐱", "🐰", "🦊", "🐻"]
    let roundsTotal = 5
    let subroundsTotal = 3
    private let baseMs: Double = 6_000
    private let subStepMs: Double = 1_500
    private let floorMs: Double = 1_500

    private(set) var round = 1
    private(set) var subround = 1
    private(set) var done = false
    private(set) var failed = false

    private(set) var cards: [Card] = []
    private var oddId = -1
    private(set) var wrongPicks: [Int] = []
    private var nextId = 0

    init() { deal() }

    var roundSeconds: Double { max(baseMs - Double(subround - 1) * subStepMs, floorMs) / 1000 }
    var isOver: Bool { done || failed }
    var lost: Bool { failed }

    private func deal() {
        wrongPicks.removeAll()
        let variety = min(max(round + 1, 2), pool.count)
        let total = min(max(round + 2, 3), 8)
        let types = Array(pool.prefix(variety))

        var base: [String: Int] = [:]
        for t in types { base[t] = 0 }
        for _ in 0..<total { let t = types.randomElement()!; base[t]! += 1 }

        var odd = base
        let from = types.filter { (odd[$0] ?? 0) > 0 }.randomElement()!
        let to = types.filter { $0 != from }.randomElement()!
        odd[from]! -= 1
        odd[to, default: 0] += 1

        let oddIdx = Int.random(in: 0..<6)
        cards = (0..<6).map { i in
            let counts = i == oddIdx ? odd : base
            // Canonical order (matches Android: no shuffle, so matching cards render identically).
            let ordered = pool.map { ($0, counts[$0] ?? 0) }
            let c = Card(id: nextId, counts: ordered); nextId += 1; return c
        }
        oddId = cards[oddIdx].id
    }

    func pick(_ id: Int) {
        guard cards.contains(where: { $0.id == id }) else { return }
        if wrongPicks.contains(id) { return }
        if id == oddId { advance() }
        else {
            wrongPicks.append(id)
            if wrongPicks.count >= 2 { failed = true }
        }
    }

    func timeout() { failed = true }

    private func advance() {
        if subround < subroundsTotal { subround += 1; deal(); return }
        if round >= roundsTotal { done = true; return }
        round += 1; subround = 1; deal()
    }
}

// MARK: - Alphabet Lock

@Observable
@MainActor
final class AlphabetLockEngine {
    struct Card: Identifiable { let id: Int; let letter: String }

    let total = 9
    private(set) var order: [String]
    private(set) var cards: [Card]
    private(set) var revealed: [Int] = []
    private(set) var wrongCard: Int?
    private(set) var done = false

    init() {
        let start = Int.random(in: 0...(26 - total))   // first letter, A...R
        let scalarA = Int(("A" as Unicode.Scalar).value)
        let ord = (0..<total).map { String(Unicode.Scalar(scalarA + start + $0)!) }
        order = ord
        cards = ord.shuffled().enumerated().map { Card(id: $0.offset, letter: $0.element) }
    }

    var progress: Int { revealed.count }
    var wrong: Bool { wrongCard != nil }
    var isOver: Bool { done }
    var lost: Bool { false }

    func isFaceUp(_ c: Card) -> Bool { revealed.contains(c.id) || c.id == wrongCard }

    func flip(_ id: Int) {
        if wrongCard != nil { return }
        guard let card = cards.first(where: { $0.id == id }) else { return }
        if revealed.contains(id) { return }
        if card.letter == order[progress] {
            revealed.append(id)
            if revealed.count == total { done = true }
        } else {
            wrongCard = id
        }
    }

    func hide() { revealed.removeAll(); wrongCard = nil }
}
