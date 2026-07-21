import SwiftUI

/// Catalogue metadata for one Brain Arcade card game. Drives the hub list and
/// the per-game "How to play" copy. A SwiftUI port of the Android
/// `CardGameMeta` (solo games only — the offline subset of the Brain Arcade).
struct ArcadeGame: Identifiable, Sendable {
    let slug: String
    let title: String
    let emoji: String
    let tagline: String
    let accent: Color
    let ages: String
    let blurb: String
    let how: [String]

    var id: String { slug }

    /// The eight games that run fully offline on-device (solo mode).
    static let all: [ArcadeGame] = [
        ArcadeGame(
            slug: "make-ten", title: "Make Ten", emoji: "🔟",
            tagline: "Pair up cards that add to 10", accent: Theme.teal, ages: "Ages 5–8",
            blurb: "Tap two cards that add up to exactly 10 to clear them. Sweep the whole board to win — how fast can you do it?",
            how: [
                "Look for two cards that add up to 10 (like 6 and 4).",
                "Tap the first card, then its partner — they clear away.",
                "Every card has a partner, so there's always a move.",
                "Clear the whole board to win. Race the clock!",
            ]),
        ArcadeGame(
            slug: "animal-count", title: "Animal Count", emoji: "🐾",
            tagline: "Spot the right animal count", accent: Theme.orange, ages: "Ages 4–7",
            blurb: "An animal lights up and a number is called. Race the timer to tap the card with exactly that many — before the clock runs out!",
            how: [
                "An animal lights up, and a number (0–2) is called.",
                "Tap the card with exactly that many of that animal.",
                "Three speed-rounds per animal — fresh cards, less time each.",
                "One slip is okay; a second wrong tap or the timer ends the game. Clear all 5 animals to win!",
            ]),
        ArcadeGame(
            slug: "odd-one-out", title: "Odd One Out", emoji: "🔍",
            tagline: "Spot the card that's different", accent: Theme.purple, ages: "Ages 5–9",
            blurb: "Lots of cards match — one doesn't. Find the odd card out before the timer runs out!",
            how: [
                "The cards show the same animals — one is different.",
                "Tap the card that doesn't match the others.",
                "Three speed-rounds each get trickier, with less time.",
                "One slip is okay; a second wrong tap or the timer ends the game. Clear all the rounds to win!",
            ]),
        ArcadeGame(
            slug: "alphabet-lock", title: "Alphabet Lock", emoji: "🔤",
            tagline: "Flip the letters in ABC order", accent: Theme.blue, ages: "Ages 5–8",
            blurb: "Nine letters hide in a grid. Flip them in alphabetical order — but one wrong flip turns them all back over! Remember where they are to crack the lock.",
            how: [
                "Nine letters hide in the grid, face down.",
                "Flip them in ABC order — the smallest letter first.",
                "Flip a wrong letter and they all turn back over!",
                "Remember the spots and flip all nine in order to win.",
            ]),
        ArcadeGame(
            slug: "memory-match", title: "Memory Match", emoji: "🧠",
            tagline: "Flip and find the pairs", accent: Theme.purple, ages: "All ages",
            blurb: "Flip the cards two at a time and match each word with its picture. Clear the whole board to win!",
            how: [
                "Flip two cards on your go.",
                "Match a word with its matching picture (like \u{201C}plant\u{201D} and 🌱).",
                "A match clears the pair; a miss flips them back.",
                "Find every pair to win.",
            ]),
        ArcadeGame(
            slug: "tower-tumble", title: "Tower Tumble", emoji: "🃏",
            tagline: "Climb the piles, empty your hand", accent: Theme.pink, ages: "Ages 6–10",
            blurb: "Stack cards higher and higher on four piles. Play a 10 to topple a tower! Empty your hand to win.",
            how: [
                "Place a card HIGHER than the top of any pile.",
                "Play a 10 to clear a pile — then it can start fresh.",
                "Stuck with no move? You pass and the piles reset.",
                "Empty your hand to win.",
            ]),
        ArcadeGame(
            slug: "number-hunt", title: "Number Hunt", emoji: "🔢",
            tagline: "Make the target number", accent: Theme.blue, ages: "Ages 7–11",
            blurb: "Hunt for cards that hit the target — one card that equals it, or two that add or subtract to it. Empty your hand to win!",
            how: [
                "Discard ONE card that equals the target number.",
                "Or discard TWO cards that add up to — or subtract to — the target.",
                "Can't discard? Draw a card.",
                "Empty your hand to win.",
            ]),
        ArcadeGame(
            slug: "beat-the-die", title: "Beat the Die", emoji: "🎲",
            tagline: "Roll, then beat it", accent: Theme.green, ages: "Ages 6–10",
            blurb: "Roll the dice, then throw down one or two cards that add up to at least the roll. Can't beat it? Draw. Empty your hand to win!",
            how: [
                "Roll the 6-sided die at the start of your turn.",
                "Discard ONE or TWO cards that add up to at least the roll.",
                "Can't beat the die? Draw a card instead.",
                "Empty your hand to win.",
            ]),
    ]
}

/// Local best-time tally for the solo arcade games, persisted to `UserDefaults`.
/// Times only — no scores, accounts, or personal data. Mirrors the Android
/// `recordSoloBest`/`soloBest` helpers.
@MainActor
enum ArcadeBest {
    private static func key(_ slug: String) -> String { "ai4kids.arcade.best.\(slug)" }

    static func best(_ slug: String) -> TimeInterval? {
        let v = UserDefaults.standard.double(forKey: key(slug))
        return v > 0 ? v : nil
    }

    /// Records `seconds` if it beats the stored best (or none exists yet).
    static func record(_ slug: String, seconds: TimeInterval) {
        guard seconds > 0 else { return }
        if let existing = best(slug), existing <= seconds { return }
        UserDefaults.standard.set(seconds, forKey: key(slug))
    }

    /// Formats a duration as `m:ss`.
    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
