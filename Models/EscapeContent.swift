import SwiftUI

// Escape Room content — a SwiftUI port of the Android LibGDX escape game's five
// levels (solo play only; the Android co-op/network layer is intentionally not
// ported — this app is fully offline).

// MARK: - Puzzle definitions

/// A puzzle a room's station opens. The first MCQ option is always the correct
/// one (options are shuffled at presentation time).
enum EscapePuzzle: Sendable {
    /// Keypad code entry. `iconField` (optional) draws a 12-cell field of
    /// pictograms; cells with value -1 are robots the child must count.
    case numberLock(code: String, prompt: String, iconField: [Int]?)
    /// Put three shuffled step cards in the right order.
    case order(heading: String, steps: [String])
    /// Symbol cipher: an 8-glyph legend maps glyphs to letters; decode `answer`.
    case cipher(legend: String, answer: String)
    /// Find the hidden words by dragging across the grid. Powered down until
    /// all `sources` rooms are solved. Completing announces the crossing cell.
    case wordSearch(words: [String], grid: [String], crossCol: Int, crossRow: Int, sources: [String])
    case mcq(question: String, options: [String])
    /// Rotate 3×3 pipes so power flows from the source to the bulb.
    case circuit
    /// Share `total` treats fairly among the animals with +/− steppers.
    case fair(animals: [String], total: Int)
    /// Sort phrases into Kind vs Mean.
    case sortKind
    /// Torch-lit maze with honesty signposts (6 random variants).
    case maze
    /// Unscramble one word after another from letter tiles.
    case unscramble(words: [String], hints: [String])
    /// Drag the four words into their numbered rows; a highlighted column
    /// spells the secret word.
    case crossword
    /// Spell `word` in symbols using the letter↔glyph key shown.
    case symbolLock(word: String)
}

/// Phrases for the kindness Sort puzzle (text, isKind).
let escapeKindnessItems: [(String, Bool)] = [
    ("Want to play with us?", true),
    ("You can't sit here!", false),
    ("Great try — well done!", true),
    ("Nobody likes you.", false),
    ("Here, let me help you up.", true),
    ("That's a dumb idea.", false),
]

/// Crossword rows for the Lion City Carnival: (number, word, column offset).
/// Column `escapeCrosswordSecretCol` spells L-I-O-N top to bottom.
let escapeCrosswordRows: [(num: Int, word: String, offset: Int)] = [
    (1, "LAKSA", 5),
    (2, "DIWALI", 4),
    (3, "ORCHID", 5),
    (4, "DURIAN", 0),
]
let escapeCrosswordSecretCol = 5

// MARK: - Maze variants (Honesty Maze)

struct EscapeMazeSign: Sendable {
    let row: Int
    let col: Int
    let text: String
}

struct EscapeMazeVariant: Sendable {
    /// 11 rows of 11 chars: `#` wall, `.` path, `S` start, `G` goal.
    let rows: [String]
    let signs: [EscapeMazeSign]
}

let escapeMazeVariants: [EscapeMazeVariant] = [
    EscapeMazeVariant(rows: [
        "###########", "#S....#...#", "#####.###.#", "#...#.....#", "#.#.#####.#",
        "#G#...#...#", "###.###.###", "#...#...#.#", "#.###.###.#", "#.........#", "###########",
    ], signs: [
        EscapeMazeSign(row: 3, col: 9, text: "You forgot your homework. Up: 'Pretend you lost it' (a lie). Down: 'Tell the teacher the truth'."),
        EscapeMazeSign(row: 9, col: 5, text: "You knocked over a plant. Right: 'Blame the cat' (a lie). Left: 'Own up and help clean it'."),
        EscapeMazeSign(row: 5, col: 3, text: "You found a lost pen. Right: 'Keep it secretly' (a lie). Up: 'Give it back honestly'."),
    ]),
    EscapeMazeVariant(rows: [
        "###########", "#S#.......#", "#.###.###.#", "#...#.#G..#", "###.#.#####",
        "#...#.....#", "#.###.###.#", "#.#...#...#", "#.#####.#.#", "#.......#.#", "###########",
    ], signs: [
        EscapeMazeSign(row: 7, col: 9, text: "You knocked over a plant. Down: 'Blame the cat' (a lie). Up: 'Own up and help clean it'."),
        EscapeMazeSign(row: 5, col: 5, text: "You found a lost pen. Down: 'Keep it secretly' (a lie). Up: 'Give it back honestly'."),
        EscapeMazeSign(row: 1, col: 5, text: "You broke a toy at a friend's house. Left: 'Hide it and say nothing' (a lie). Right: 'Tell your friend and say sorry'."),
    ]),
    EscapeMazeVariant(rows: [
        "###########", "#S#.....#G#", "#.#.###.#.#", "#.#...#...#", "#.#.#.#####",
        "#.#.#.....#", "#.#####.#.#", "#.....#.#.#", "#####.###.#", "#.........#", "###########",
    ], signs: [
        EscapeMazeSign(row: 9, col: 5, text: "You found a lost pen. Left: 'Keep it secretly' (a lie). Right: 'Give it back honestly'."),
        EscapeMazeSign(row: 5, col: 7, text: "You broke a toy at a friend's house. Down: 'Hide it and say nothing' (a lie). Left: 'Tell your friend and say sorry'."),
        EscapeMazeSign(row: 3, col: 3, text: "You scored extra points by mistake. Down: 'Keep quiet about it' (a lie). Up: 'Tell the teacher the truth'."),
    ]),
    EscapeMazeVariant(rows: [
        "###########", "#S..#.....#", "###.#.###.#", "#G#.#...#.#", "#.#.#####.#",
        "#.#.......#", "#.#######.#", "#...#.....#", "#.###.#####", "#.........#", "###########",
    ], signs: [
        EscapeMazeSign(row: 5, col: 9, text: "You broke a toy at a friend's house. Up: 'Hide it and say nothing' (a lie). Down: 'Tell your friend and say sorry'."),
        EscapeMazeSign(row: 9, col: 5, text: "You scored extra points by mistake. Right: 'Keep quiet about it' (a lie). Left: 'Tell the teacher the truth'."),
        EscapeMazeSign(row: 7, col: 1, text: "You forgot your homework. Right: 'Pretend you lost it' (a lie). Up: 'Tell the teacher the truth'."),
    ]),
    EscapeMazeVariant(rows: [
        "###########", "#S......#.#", "#######.#.#", "#G....#...#", "#####.###.#",
        "#.....#...#", "#.###.#.###", "#...#.#.#.#", "#.#.###.#.#", "#.#.......#", "###########",
    ], signs: [
        EscapeMazeSign(row: 9, col: 7, text: "You scored extra points by mistake. Right: 'Keep quiet about it' (a lie). Left: 'Tell the teacher the truth'."),
        EscapeMazeSign(row: 7, col: 1, text: "You forgot your homework. Down: 'Pretend you lost it' (a lie). Up: 'Tell the teacher the truth'."),
        EscapeMazeSign(row: 5, col: 5, text: "You knocked over a plant. Down: 'Blame the cat' (a lie). Up: 'Own up and help clean it'."),
    ]),
    EscapeMazeVariant(rows: [
        "###########", "#S..#.....#", "###.###.#.#", "#G#.....#.#", "#.#######.#",
        "#...#.....#", "#.###.#####", "#...#...#.#", "#.#.###.#.#", "#.#.......#", "###########",
    ], signs: [
        EscapeMazeSign(row: 9, col: 7, text: "You forgot your homework. Right: 'Pretend you lost it' (a lie). Left: 'Tell the teacher the truth'."),
        EscapeMazeSign(row: 7, col: 1, text: "You knocked over a plant. Down: 'Blame the cat' (a lie). Up: 'Own up and help clean it'."),
        EscapeMazeSign(row: 5, col: 1, text: "You found a lost pen. Right: 'Keep it secretly' (a lie). Up: 'Give it back honestly'."),
    ]),
]

// MARK: - Rooms & levels

enum EscapeFloorKind: Sendable {
    case metal, concrete, stone, tile, wood, grass, panel
}

struct EscapeRoomDef: Identifiable, Sendable {
    let id: String
    let title: String
    var gx: Int
    var gy: Int
    var gw: Int = 1
    var gh: Int = 1
    var puzzle: EscapePuzzle? = nil
    /// Room id whose puzzle must be solved before this station unlocks.
    var requires: String? = nil
    var requiresAll: [String] = []
    /// Text added to the clue list when this room's puzzle is solved.
    var clue: String? = nil
    var floorKind: EscapeFloorKind? = nil
    /// Two decorative emoji drawn faintly in the room corners.
    var decor: [String] = []
}

enum EscapeClueArt: Sendable {
    case none
    /// Robot Lab sketch: "digit 1 = row, digit 2 = column" crossing hint.
    case rowsAndColumns
    /// Superhero Tower map: numbered cores → chargers → the Suit.
    case towerMap
}

struct EscapeLevelDef: Identifiable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let blurb: String
    let cols: Int
    let rows: Int
    let rooms: [EscapeRoomDef]
    let doors: [[String]]
    let spawn: String
    let exit: String
    var clueRoom: String? = nil
    var clueArt: EscapeClueArt = .none
    /// Charger room ids, in core order. Cores spawn in `coreRoom` unless
    /// `directDeliver` (History Vault): then each "core" is an artefact sealed
    /// inside its own gallery until that gallery's puzzle is solved.
    var cores: [String] = []
    var coreRoom: String? = nil
    var suitRoom: String? = nil
    var directDeliver: Bool = false
    var artefacts: [String] = []   // artefact names + emoji, aligned with cores
    var artefactEmoji: [String] = []
    /// Bottle recycling chain (Green Workshop): bottles spawn in these rooms,
    /// get washed at the sink and recycled at the deposit (both in `sinkRoom`).
    var bottleHomes: [String] = []
    var sinkRoom: String? = nil
    var bottleGateRoom: String? = nil
    let bg: Color
    let floorTint: Color
    let floorKind: EscapeFloorKind
    let accent: Color

    var room: [String: EscapeRoomDef] {
        Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
    }
    var totalStations: Int { rooms.filter { $0.puzzle != nil }.count }
}

enum EscapeContent {
    static let levels: [EscapeLevelDef] = [robotLab, tower, greenLab, vault, carnival]

    // L0 — Robot Lab
    static let robotLab = EscapeLevelDef(
        id: "robot-lab", name: "Robot Lab", emoji: "🤖",
        blurb: "Count robots, crack the cipher and find the door code!",
        cols: 3, rows: 3,
        rooms: [
            EscapeRoomDef(id: "entrance", title: "Entrance", gx: 0, gy: 0, decor: ["🚪", "🧰"]),
            EscapeRoomDef(id: "panel", title: "Control Panel", gx: 1, gy: 0,
                          puzzle: .numberLock(code: "6", prompt: "Count the robots",
                                              iconField: [2, -1, -1, 1, -1, 0, -1, 7, 4, -1, 2, -1]),
                          clue: "Display: ROBOT", decor: ["⚙️", "🖥️"]),
            EscapeRoomDef(id: "keypad", title: "Exit Chamber", gx: 2, gy: 0,
                          puzzle: .numberLock(code: "54", prompt: "Enter the 2-digit door code", iconField: nil),
                          requires: "poster", decor: ["⚙️", "🔒"]),
            EscapeRoomDef(id: "atrium", title: "Main Lab", gx: 0, gy: 1, gw: 2, decor: ["⚙️", "🔬"]),
            EscapeRoomDef(id: "poster", title: "Word Display", gx: 2, gy: 1, gh: 2,
                          puzzle: .wordSearch(words: ["ROBOT", "LEARN", "GEAR"],
                                              grid: ["ZXQKVWYJ",
                                                     "CPDGHUFM",
                                                     "WYVEJPDH",
                                                     "KVQAJCZF",
                                                     "XZJROBOT",
                                                     "MPUDKVQX",
                                                     "HLEARNYP",
                                                     "FCZJWQVD"],
                                              crossCol: 3, crossRow: 4,
                                              sources: ["panel", "robot", "decoder"]),
                          decor: ["🖥️", "📺"]),
            EscapeRoomDef(id: "decoder", title: "Symbol Decoder", gx: 0, gy: 2,
                          puzzle: .cipher(legend: "GEARSTNO", answer: "GEAR"),
                          clue: "Display: GEAR", decor: ["🖥️", "⚙️"]),
            EscapeRoomDef(id: "robot", title: "Robot Helper", gx: 1, gy: 2,
                          puzzle: .order(heading: "Teach the robot to spot cats!",
                                         steps: ["Show the robot lots of cat photos",
                                                 "The robot spots the pattern",
                                                 "The robot guesses 'cat!' on a new photo"]),
                          clue: "Display: LEARN", decor: ["🤖", "⚙️"]),
        ],
        doors: [["entrance", "panel"], ["entrance", "atrium"], ["atrium", "decoder"],
                ["atrium", "robot"], ["atrium", "poster"], ["panel", "keypad"], ["poster", "keypad"]],
        spawn: "entrance", exit: "keypad", clueRoom: "atrium", clueArt: .rowsAndColumns,
        bg: Color(red: 0.10, green: 0.14, blue: 0.24),
        floorTint: Color(red: 0.24, green: 0.34, blue: 0.50),
        floorKind: .metal,
        accent: Color(red: 0.38, green: 0.55, blue: 0.80)
    )

    // L1 — Superhero Tower (kindness castle)
    static let tower = EscapeLevelDef(
        id: "tower", name: "Superhero Tower", emoji: "🦸",
        blurb: "Charge the three hero cores and power up the Suit!",
        cols: 2, rows: 4,
        rooms: [
            EscapeRoomDef(id: "foyer", title: "Foyer", gx: 0, gy: 0, gw: 2, decor: ["🛋️", "🪴"]),
            EscapeRoomDef(id: "honesty", title: "Honesty Charger", gx: 0, gy: 1,
                          puzzle: .maze, clue: "Honesty core ready", decor: ["🔋", "💙"]),
            EscapeRoomDef(id: "fairness", title: "Fairness Charger", gx: 1, gy: 1,
                          puzzle: .fair(animals: ["🐶", "🐰", "🦊"], total: 9),
                          clue: "Fairness core ready", decor: ["🔋", "💛"]),
            EscapeRoomDef(id: "landing", title: "Landing", gx: 0, gy: 2, gw: 2, decor: ["🪜", "🏮"]),
            EscapeRoomDef(id: "attic", title: "The Suit", gx: 0, gy: 3,
                          puzzle: .unscramble(words: ["KIND", "TRUE", "FAIR"],
                                              hints: ["Caring and friendly to others.",
                                                      "Honest — not a lie!",
                                                      "Everyone gets an equal share."]),
                          decor: ["🦸", "🏆"]),
            EscapeRoomDef(id: "kindness", title: "Kindness Charger", gx: 1, gy: 3,
                          puzzle: .sortKind, clue: "Kindness core ready", decor: ["🔋", "💚"]),
        ],
        doors: [["foyer", "fairness"], ["fairness", "honesty"], ["honesty", "landing"],
                ["landing", "kindness"], ["kindness", "attic"]],
        spawn: "foyer", exit: "attic", clueRoom: "landing", clueArt: .towerMap,
        cores: ["fairness", "honesty", "kindness"], coreRoom: "landing", suitRoom: "attic",
        bg: Color(red: 0.15, green: 0.12, blue: 0.24),
        floorTint: Color(red: 0.38, green: 0.30, blue: 0.50),
        floorKind: .panel,
        accent: Color(red: 0.86, green: 0.32, blue: 0.42)
    )

    // L2 — Green Workshop (L-shape: voids at (2,1) and (2,2))
    static let greenLab = EscapeLevelDef(
        id: "green-lab", name: "Green Workshop", emoji: "🌱",
        blurb: "Recycle the bottles, fix the circuit and decode POWER!",
        cols: 3, rows: 3,
        rooms: [
            EscapeRoomDef(id: "lobby", title: "Lobby", gx: 0, gy: 0, decor: ["🪴", "🚪"]),
            EscapeRoomDef(id: "panel", title: "Solar Panel", gx: 1, gy: 0, gw: 2,
                          puzzle: .mcq(question: "Which power comes from the sun and never runs out?",
                                       options: ["Solar power", "Burning coal", "Plastic bags"]),
                          clue: "Sun = renewable", decor: ["🔆", "🪴"]),
            EscapeRoomDef(id: "bins", title: "Recycling Plant", gx: 0, gy: 1, gh: 2,
                          puzzle: .order(heading: "Put the recycling steps in order",
                                         steps: ["Empty and rinse the bottle",
                                                 "Drop it in the recycling bin",
                                                 "It's made into something new!"]),
                          clue: "Reuse, don't bin", decor: ["♻️", "🪴"]),
            EscapeRoomDef(id: "circuit", title: "Power Circuit", gx: 1, gy: 1,
                          puzzle: .circuit, clue: "Power flows", decor: ["💡", "🔋"]),
            EscapeRoomDef(id: "loft", title: "Exit Decoder", gx: 1, gy: 2,
                          puzzle: .cipher(legend: "POWERSUN", answer: "POWER"),
                          requiresAll: ["panel", "bins", "circuit"], decor: ["🖥️", "🔒"]),
        ],
        doors: [["lobby", "panel"], ["lobby", "bins"], ["bins", "circuit"], ["circuit", "loft"]],
        spawn: "lobby", exit: "loft",
        bottleHomes: ["lobby", "panel", "bins"], sinkRoom: "bins", bottleGateRoom: "circuit",
        bg: Color(red: 0.08, green: 0.16, blue: 0.12),
        floorTint: Color(red: 0.22, green: 0.44, blue: 0.30),
        floorKind: .concrete,
        accent: Color(red: 0.34, green: 0.66, blue: 0.42)
    )

    // L3 — History Vault (Singapore history)
    static let vault = EscapeLevelDef(
        id: "vault", name: "History Vault", emoji: "🏛️",
        blurb: "Collect the artefacts and fill the Time Capsule!",
        cols: 3, rows: 3,
        rooms: [
            EscapeRoomDef(id: "hall", title: "Heritage Hall", gx: 0, gy: 0, gw: 3, decor: ["🏮", "📜"]),
            EscapeRoomDef(id: "west", title: "Founding Gallery", gx: 0, gy: 1, gh: 2,
                          puzzle: .mcq(question: "In which year did Raffles land and found modern Singapore?",
                                       options: ["1819", "1942", "1965"]),
                          clue: "Treaty: 1819", decor: ["📜", "🖼️"]),
            EscapeRoomDef(id: "core", title: "Time Capsule", gx: 1, gy: 1, decor: ["🏺", "✨"]),
            EscapeRoomDef(id: "east", title: "Independence Hall", gx: 2, gy: 1, gh: 2,
                          puzzle: .numberLock(code: "1965",
                                              prompt: "What year did Singapore become independent?",
                                              iconField: nil),
                          clue: "Flag: 1965", decor: ["🚩", "🖼️"]),
            EscapeRoomDef(id: "top", title: "Lion City Room", gx: 1, gy: 2,
                          puzzle: .unscramble(words: ["SINGA", "PURA"],
                                              hints: ["In Malay, the word for 'lion'.",
                                                      "In Malay, this means 'city' — put it after Singa for Singapore's old name."]),
                          clue: "Merlion: Singapura", decor: ["🦁", "🏮"]),
        ],
        doors: [["hall", "west"], ["hall", "east"], ["west", "core"], ["east", "core"], ["core", "top"]],
        spawn: "hall", exit: "core",
        cores: ["west", "east", "top"], suitRoom: "core", directDeliver: true,
        artefacts: ["Treaty scroll", "National Flag", "Merlion"],
        artefactEmoji: ["📜", "🚩", "🦁"],
        bg: Color(red: 0.17, green: 0.13, blue: 0.09),
        floorTint: Color(red: 0.44, green: 0.36, blue: 0.22),
        floorKind: .stone,
        accent: Color(red: 0.72, green: 0.52, blue: 0.28)
    )

    // L4 — Lion City Carnival (plus shape: voids at (0,0), (0,2), (2,0))
    static let carnival = EscapeLevelDef(
        id: "carnival", name: "Lion City Carnival", emoji: "🎪",
        blurb: "Solve the food, festival, flower and fruit puzzles — then spell LION!",
        cols: 3, rows: 3,
        rooms: [
            EscapeRoomDef(id: "food", title: "Hawker Stall", gx: 1, gy: 0,
                          puzzle: .order(heading: "Put the laksa steps in order",
                                         steps: ["Simmer the spicy coconut-milk broth",
                                                 "Add the noodles, prawns and tofu puffs",
                                                 "Top with cockles and serve hot"]),
                          clue: "1 = LAKSA", decor: ["🍜", "🪑"]),
            EscapeRoomDef(id: "festival", title: "Little India", gx: 0, gy: 1,
                          puzzle: .unscramble(words: ["DIWALI"],
                                              hints: ["The Hindu festival of lights, with oil lamps and colourful rangoli."]),
                          clue: "2 = DIWALI", decor: ["🪔", "🌸"]),
            EscapeRoomDef(id: "hall", title: "Grand Hall", gx: 1, gy: 1,
                          puzzle: .crossword,
                          requiresAll: ["food", "festival", "flower", "fruit"], decor: ["🏮", "🏮"]),
            EscapeRoomDef(id: "flower", title: "Gardens", gx: 2, gy: 1,
                          puzzle: .mcq(question: "What is Singapore's national flower?",
                                       options: ["Orchid", "Rose", "Tulip"]),
                          clue: "3 = ORCHID", floorKind: .grass, decor: ["🪴", "🌺"]),
            EscapeRoomDef(id: "fruit", title: "Fruit Stall", gx: 1, gy: 2,
                          puzzle: .cipher(legend: "DURIANOS", answer: "DURIAN"),
                          clue: "4 = DURIAN", floorKind: .wood, decor: ["🍎", "🍌"]),
            EscapeRoomDef(id: "exit", title: "Exit Panel", gx: 2, gy: 2,
                          puzzle: .symbolLock(word: "LION"),
                          requires: "hall", decor: ["🔒", "🏮"]),
        ],
        doors: [["hall", "food"], ["hall", "festival"], ["hall", "flower"],
                ["hall", "fruit"], ["flower", "exit"]],
        spawn: "hall", exit: "exit",
        bg: Color(red: 0.18, green: 0.10, blue: 0.12),
        floorTint: Color(red: 0.48, green: 0.28, blue: 0.26),
        floorKind: .tile,
        accent: Color(red: 0.86, green: 0.34, blue: 0.36)
    )
}
