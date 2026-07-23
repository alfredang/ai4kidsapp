import SwiftUI
import Observation

/// Phonics Quest — an offline, on-device phonics adventure for ages 4–6.
///
/// A map of phonics "worlds", bite-size mini-games, and gamified progression
/// with stars and unlocking. Everything runs locally — whole words are spoken
/// with the system speech synthesizer and isolated sounds play bundled clips,
/// so there's no network, no AI service, no accounts.
///
/// Ported from the Android app's `PhonicsContent.kt` (same worlds, same rounds).

/// The mini-game kinds a world can use.
enum PhonicsKind: Sendable {
    case pop, build, rhyme, listen, blend, digraph
}

/// A picture choice: an emoji plus the word it depicts.
struct PictureOption: Sendable, Hashable {
    let emoji: String
    let word: String
}

/// "Pop the Phoneme" round: which starting *sound* does this picture make?
/// `options` and `answer` are phoneme slugs (bundled mp3 clips, played by
/// `PhonicsAudio`) — keyed by sound, not letter, since the child decides by
/// ear. `letter` is the grapheme that sound maps to in this word (e.g. Cat →
/// 'C' for the /k/ sound).
struct PopRound: Sendable {
    let emoji: String
    let word: String
    let answer: String
    let options: [String]
    let letter: Character
}

/// "Build the Word" round: build the word from letter tiles by *sound*. As each
/// correct letter lands, its phoneme clip plays (blending, not letter names);
/// `sounds` has one phoneme slug per letter of `word`, with "" marking a silent
/// letter (e.g. the B in LAMB) — those play no sound, which teaches the silence.
struct BuildRound: Sendable {
    let emoji: String
    let word: String
    let sounds: [String]

    init(_ emoji: String, _ word: String, _ sounds: [String]) {
        precondition(sounds.count == word.count, "sounds must have one entry per letter in \"\(word)\"")
        self.emoji = emoji
        self.word = word
        self.sounds = sounds
    }

    /// True if any letter in this word is silent (its slug is empty).
    var hasSilentLetters: Bool { sounds.contains("") }
}

/// "Rhyme Time" round: pick the option that rhymes with the target.
struct RhymeRound: Sendable {
    let emoji: String
    let word: String
    let options: [PictureOption]
    let answer: Int
}

/// "Listen & Find" round: hear the word, then tap the matching word among
/// similar-sounding choices (no pictures — the child decides by listening).
struct ListenRound: Sendable {
    let word: String
    let options: [String]
    let answer: Int
}

/// "Sound Blender" round: hear each sound, blend them, then tap the matching
/// picture — decoded purely by ear (no letters shown).
struct BlendRound: Sendable {
    let word: String
    let sounds: [String]
    let options: [PictureOption]
    let answer: Int
}

/// "Buddy Sounds" round: hear a two-letter (digraph) sound, then pick the letter
/// team that spells it — the child must map the sound to its spelling, so there's
/// no read-the-word shortcut.
struct DigraphRound: Sendable {
    let sound: String
    let teams: [String]
    let answer: Int
    let exampleEmoji: String
    let exampleWord: String
}

/// One world on the adventure map. Only the list matching `kind` is populated.
struct PhonicsStage: Sendable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
    let color: Color
    let kind: PhonicsKind
    var pop: [PopRound] = []
    var build: [BuildRound] = []
    var rhyme: [RhymeRound] = []
    var listen: [ListenRound] = []
    var blend: [BlendRound] = []
    var digraph: [DigraphRound] = []

    var rounds: Int {
        switch kind {
        case .pop: pop.count
        case .build: build.count
        case .rhyme: rhyme.count
        case .listen: listen.count
        case .blend: blend.count
        case .digraph: digraph.count
        }
    }
}

enum PhonicsContent {
    /// The seven worlds of Phonics Quest.
    static let stages: [PhonicsStage] = [
        PhonicsStage(
            id: "letters-land",
            title: "Letters Land",
            subtitle: "Starting sounds",
            emoji: "🅰️",
            color: Theme.pink,
            kind: .pop,
            // Distractors are phonemes that clearly *sound* different from the
            // answer (a child picks by ear), e.g. Cat's /k/ vs /t/ and /s/ — not
            // C/K/T, since C and K are the same /k/ sound.
            pop: [
                PopRound(emoji: "🍎", word: "Apple", answer: "v_a_short", options: ["v_a_short", "c_b", "c_s"], letter: "A"),
                PopRound(emoji: "🐻", word: "Bear", answer: "c_b", options: ["c_b", "c_d", "c_m"], letter: "B"),
                PopRound(emoji: "🐱", word: "Cat", answer: "c_k", options: ["c_k", "c_t", "c_s"], letter: "C"),
                PopRound(emoji: "🐶", word: "Dog", answer: "c_d", options: ["c_d", "c_b", "c_p"], letter: "D"),
                PopRound(emoji: "🥚", word: "Egg", answer: "v_e_short", options: ["v_e_short", "v_a_short", "v_i_short"], letter: "E"),
                PopRound(emoji: "🌙", word: "Moon", answer: "c_m", options: ["c_m", "c_n", "c_w"], letter: "M"),
            ]),
        PhonicsStage(
            id: "blend-bridge",
            title: "Blend Bridge",
            subtitle: "Build short words",
            emoji: "🌉",
            color: Theme.orange,
            kind: .build,
            // CVC words: one sound per letter, so tapping a tile sounds it out and
            // a full build blends into the word (/k/-/æ/-/t/ → "cat").
            build: [
                BuildRound("🐱", "CAT", ["c_k", "v_a_short", "c_t"]),
                BuildRound("🐶", "DOG", ["c_d", "v_o_short", "c_g"]),
                BuildRound("☀️", "SUN", ["c_s", "v_u_short", "c_n"]),
                BuildRound("🎩", "HAT", ["c_h", "v_a_short", "c_t"]),
                BuildRound("🚌", "BUS", ["c_b", "v_u_short", "c_s"]),
            ]),
        PhonicsStage(
            id: "silent-letters",
            title: "Whisper Woods",
            subtitle: "Silent letters",
            emoji: "🤫",
            color: Theme.purple,
            kind: .build,
            // "" marks a silent letter — it plays no sound, so the child hears
            // which letters are silent while building the word.
            build: [
                BuildRound("🐑", "LAMB", ["c_l", "v_a_short", "c_m", ""]),         // silent B
                BuildRound("🔪", "KNIFE", ["", "c_n", "d_ie", "c_f", ""]),         // silent K, E
                BuildRound("👻", "GHOST", ["c_g", "", "d_oa", "c_s", "c_t"]),      // silent H
                BuildRound("🏰", "CASTLE", ["c_k", "v_ar", "c_s", "", "c_l", ""]), // silent T, E
                BuildRound("✍️", "WRITE", ["", "c_r", "d_ie", "c_t", ""]),         // silent W, E
            ]),
        PhonicsStage(
            id: "rhyme-road",
            title: "Rhyme Road",
            subtitle: "Words that rhyme",
            emoji: "🎵",
            color: Theme.green,
            kind: .rhyme,
            rhyme: [
                RhymeRound(emoji: "🐱", word: "Cat",
                           options: [.init(emoji: "🎩", word: "Hat"), .init(emoji: "🐶", word: "Dog"), .init(emoji: "☀️", word: "Sun")], answer: 0),
                RhymeRound(emoji: "⭐", word: "Star",
                           options: [.init(emoji: "🚗", word: "Car"), .init(emoji: "🌙", word: "Moon"), .init(emoji: "🐟", word: "Fish")], answer: 0),
                RhymeRound(emoji: "🌳", word: "Tree",
                           options: [.init(emoji: "🐝", word: "Bee"), .init(emoji: "🐱", word: "Cat"), .init(emoji: "☀️", word: "Sun")], answer: 0),
                RhymeRound(emoji: "🐸", word: "Frog",
                           options: [.init(emoji: "🪵", word: "Log"), .init(emoji: "🐱", word: "Cat"), .init(emoji: "⭐", word: "Star")], answer: 0),
                RhymeRound(emoji: "🐌", word: "Snail",
                           options: [.init(emoji: "🐳", word: "Whale"), .init(emoji: "🐶", word: "Dog"), .init(emoji: "🐦", word: "Bird")], answer: 0),
            ]),
        PhonicsStage(
            id: "story-kingdom",
            title: "Story Kingdom",
            subtitle: "Listen & find",
            emoji: "👑",
            color: Theme.blue,
            kind: .listen,
            listen: [
                ListenRound(word: "Sun", options: ["Sun", "Sock", "Sand"], answer: 0),
                ListenRound(word: "Dog", options: ["Dog", "Dot", "Duck"], answer: 0),
                ListenRound(word: "Tree", options: ["Tree", "Try", "Train"], answer: 0),
                ListenRound(word: "Cat", options: ["Cat", "Cap", "Cot"], answer: 0),
                ListenRound(word: "Bear", options: ["Bear", "Bee", "Boat"], answer: 0),
            ]),
        PhonicsStage(
            id: "sound-blender",
            title: "Sound Blender",
            subtitle: "Blend sounds into words",
            emoji: "🌀",
            color: Theme.teal,
            kind: .blend,
            // Hear /p/-/i/-/g/, blend it, tap the pig. Pure decoding of CVC words
            // — fresh words (only Dog carries over from Blend Bridge) so the child
            // decodes by ear rather than recalling the earlier build.
            blend: [
                BlendRound(word: "Pig", sounds: ["c_p", "v_i_short", "c_g"],
                           options: [.init(emoji: "🐷", word: "Pig"), .init(emoji: "🐶", word: "Dog"), .init(emoji: "🐔", word: "Hen")], answer: 0),
                BlendRound(word: "Hen", sounds: ["c_h", "v_e_short", "c_n"],
                           options: [.init(emoji: "🐔", word: "Hen"), .init(emoji: "🐷", word: "Pig"), .init(emoji: "🐛", word: "Bug")], answer: 0),
                BlendRound(word: "Bug", sounds: ["c_b", "v_u_short", "c_g"],
                           options: [.init(emoji: "🐛", word: "Bug"), .init(emoji: "🐷", word: "Pig"), .init(emoji: "🥤", word: "Cup")], answer: 0),
                BlendRound(word: "Cup", sounds: ["c_k", "v_u_short", "c_p"],
                           options: [.init(emoji: "🥤", word: "Cup"), .init(emoji: "🐛", word: "Bug"), .init(emoji: "🐶", word: "Dog")], answer: 0),
                BlendRound(word: "Dog", sounds: ["c_d", "v_o_short", "c_g"],
                           options: [.init(emoji: "🐶", word: "Dog"), .init(emoji: "🐷", word: "Pig"), .init(emoji: "🐔", word: "Hen")], answer: 0),
            ]),
        PhonicsStage(
            id: "sound-buddies",
            title: "Sound Buddies",
            subtitle: "Two letters, one sound",
            emoji: "🤝",
            color: Theme.purple,
            kind: .digraph,
            // Hear a digraph SOUND, pick the two letters that spell it. The child
            // has to map the sound to its spelling, so there's no read-the-word
            // shortcut.
            digraph: [
                DigraphRound(sound: "c_sh", teams: ["sh", "ch", "th"], answer: 0, exampleEmoji: "🚢", exampleWord: "Ship"),
                DigraphRound(sound: "c_ch", teams: ["ch", "sh", "th"], answer: 0, exampleEmoji: "🍟", exampleWord: "Chip"),
                DigraphRound(sound: "c_th_unvoiced", teams: ["th", "sh", "ng"], answer: 0, exampleEmoji: "🛁", exampleWord: "Bath"),
                DigraphRound(sound: "c_ng", teams: ["ng", "sh", "ch"], answer: 0, exampleEmoji: "💍", exampleWord: "Ring"),
                DigraphRound(sound: "c_sh", teams: ["sh", "th", "ch"], answer: 0, exampleEmoji: "🐟", exampleWord: "Fish"),
            ]),
    ]

    /// Stars from mistakes: 0 → 3 stars, 1–2 → 2 stars, else 1 star.
    static func starsForMistakes(_ mistakes: Int) -> Int {
        switch mistakes {
        case 0: 3
        case 1, 2: 2
        default: 1
        }
    }
}

/// Per-stage progress (best stars 0–3) persisted to `UserDefaults`, same pattern
/// the Brain Arcade uses for best times. A stage unlocks once the previous one
/// is cleared (≥1 star). Local-only by design — no accounts, nothing collected.
@MainActor
@Observable
final class PhonicsStageStore {
    private(set) var stars: [String: Int] = [:]

    init() {
        var loaded: [String: Int] = [:]
        for stage in PhonicsContent.stages {
            let v = UserDefaults.standard.integer(forKey: "ai4kids.phonics.stage.\(stage.id)")
            if v > 0 { loaded[stage.id] = v }
        }
        stars = loaded
    }

    func stars(for stageId: String) -> Int { stars[stageId, default: 0] }

    var totalStars: Int { stars.values.reduce(0, +) }

    /// True if the stage at `index` is playable (first stage, or previous cleared).
    func isUnlocked(_ index: Int) -> Bool {
        guard index > 0 else { return true }
        return stars(for: PhonicsContent.stages[index - 1].id) >= 1
    }

    /// Record a stage result; returns the star *improvement* (0 if not a new best).
    func record(_ stageId: String, earned: Int) -> Int {
        let old = stars(for: stageId)
        guard earned > old else { return 0 }
        stars[stageId] = earned
        UserDefaults.standard.set(earned, forKey: "ai4kids.phonics.stage.\(stageId)")
        return earned - old
    }
}
