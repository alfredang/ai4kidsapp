import Foundation

/// Pure story logic for the Story Builder — deliberately free of SwiftUI so it is
/// plain, testable value-type code. `StoryBuilderView` drives this model and
/// renders it. A faithful Swift port of the Android app's `StoryEngine.kt` (which
/// in turn mirrors the web app's `src/lib/story-builder/templates.ts`).
///
/// The child picks a hero, place, magic item and mood; `buildStory` weaves a short
/// branching tale from randomized beats, so the same picks read differently each
/// time.
///
/// The tale forks TWICE — first how to solve the trouble, then what to do with the
/// magic afterwards — so there are four possible endings and a replay reads
/// differently. The second fork is OPTIONAL on `StoryBranch`: a branch without one
/// still plays as a shorter single-fork tale.

/// One pickable story ingredient (hero, place, magic item or mood).
struct StoryChoice: Sendable, Hashable, Identifiable {
    let emoji: String
    let name: String
    var id: String { name }
}

/// A node that can pose a fork — the story root, or any branch with a follow-up.
protocol StoryForkNode: Sendable {
    var forkProblem: String? { get }
    var forkChoiceA: StoryBranch? { get }
    var forkChoiceB: StoryBranch? { get }
}

/// One way the child can solve a problem. `pages` are read straight after the
/// pick. `problem` + `choiceA`/`choiceB`, when present, pose a follow-up fork —
/// they're optional so a story with only one fork is still valid and playable.
///
/// The nested branches live in an array purely to give the recursive value type
/// heap indirection (Swift structs can't directly contain themselves).
struct StoryBranch: Sendable, Hashable, StoryForkNode {
    let emoji: String
    let label: String
    let pages: [String]
    let problem: String?
    private let children: [StoryBranch]

    init(emoji: String, label: String, pages: [String],
         problem: String? = nil, choiceA: StoryBranch? = nil, choiceB: StoryBranch? = nil) {
        self.emoji = emoji
        self.label = label
        self.pages = pages
        self.problem = problem
        if let choiceA, let choiceB {
            self.children = [choiceA, choiceB]
        } else {
            self.children = []
        }
    }

    var choiceA: StoryBranch? { children.first }
    var choiceB: StoryBranch? { children.count > 1 ? children[1] : nil }

    var forkProblem: String? { problem }
    var forkChoiceA: StoryBranch? { choiceA }
    var forkChoiceB: StoryBranch? { choiceB }
}

/// A branching story woven from the picks. `pre` are the pages read before the
/// first fork; `problem` is that fork, where the child picks `choiceA` or
/// `choiceB`. Every beat has several phrasings chosen at random, so the same picks
/// read differently each time — that, plus the choices, is what keeps the builder
/// from feeling repetitive.
struct Story: Sendable, Hashable, StoryForkNode {
    let pre: [String]
    let problem: String
    let choiceA: StoryBranch
    let choiceB: StoryBranch

    var forkProblem: String? { problem }
    var forkChoiceA: StoryBranch? { choiceA }
    var forkChoiceB: StoryBranch? { choiceB }
}

/// The pages read so far along the path the child has chosen, plus the page index
/// of each fork. `forks[k]` is answered by `chosen[k]`, so the first unanswered
/// fork is `forks[chosen.count]` — that's where the child is deciding now.
struct StoryTimeline: Sendable, Hashable {
    let pages: [String]
    let forks: [Int]
}

enum StoryEngine {
    static let heroes: [StoryChoice] = [
        StoryChoice(emoji: "🦊", name: "Fox"), StoryChoice(emoji: "🐉", name: "Dragon"),
        StoryChoice(emoji: "🤖", name: "Robot"), StoryChoice(emoji: "🦄", name: "Unicorn"),
        StoryChoice(emoji: "🐼", name: "Panda"), StoryChoice(emoji: "🦉", name: "Owl"),
        StoryChoice(emoji: "🐢", name: "Turtle"), StoryChoice(emoji: "🐱", name: "Kitten"),
    ]
    static let places: [StoryChoice] = [
        StoryChoice(emoji: "🏰", name: "castle"), StoryChoice(emoji: "🌋", name: "volcano"),
        StoryChoice(emoji: "🌌", name: "galaxy"), StoryChoice(emoji: "🏝️", name: "island"),
        StoryChoice(emoji: "🌲", name: "forest"), StoryChoice(emoji: "💧", name: "waterfall"),
        StoryChoice(emoji: "🏔️", name: "snowy peak"), StoryChoice(emoji: "🪸", name: "coral reef"),
    ]
    static let objects: [StoryChoice] = [
        StoryChoice(emoji: "🗝️", name: "golden key"), StoryChoice(emoji: "🔮", name: "magic orb"),
        StoryChoice(emoji: "🎈", name: "balloon"), StoryChoice(emoji: "📕", name: "spell book"),
        StoryChoice(emoji: "🏮", name: "lantern"), StoryChoice(emoji: "🧭", name: "compass"),
        StoryChoice(emoji: "🪶", name: "feather"), StoryChoice(emoji: "🎶", name: "music box"),
    ]
    /// A mood/trait is threaded through the prose so the same hero can feel brave
    /// one time and silly the next — changing the whole tone of the story.
    static let moods: [StoryChoice] = [
        StoryChoice(emoji: "🦁", name: "brave"), StoryChoice(emoji: "🤪", name: "silly"),
        StoryChoice(emoji: "😴", name: "sleepy"), StoryChoice(emoji: "🤔", name: "curious"),
        StoryChoice(emoji: "💖", name: "kind"), StoryChoice(emoji: "🧠", name: "clever"),
        StoryChoice(emoji: "😄", name: "cheerful"), StoryChoice(emoji: "🙈", name: "shy"),
    ]

    /// "a" vs "an" — `places` has `island`, so a naive "a \(place)" reads wrong.
    static func an(_ word: String) -> String {
        guard let first = word.first?.lowercased() else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    /// One random phrasing from a pool. The pools below are all literal non-empty
    /// arrays, so the fallback never fires; it exists only to avoid a force-unwrap.
    private static func pick(_ options: [String]) -> String {
        options.randomElement() ?? options.first ?? ""
    }

    private static func celebrations(_ h: StoryChoice, _ p: StoryChoice, _ o: StoryChoice) -> [String] {
        [
            "Everyone cheered for the \(h.name) \(h.emoji)! The \(p.name) \(p.emoji) sparkled brighter than ever. ✨",
            "What a day! The \(h.name) \(h.emoji) laughed and danced with all the new friends. 🎶",
            "The \(o.name) \(o.emoji) hummed a happy tune, and the whole \(p.name) \(p.emoji) joined in. 🎵",
            "Hooray! The \(h.name) \(h.emoji) jumped for joy as the \(p.name) \(p.emoji) filled with giggles. 😄",
            "Confetti swirled through the \(p.name) \(p.emoji) as everyone thanked the \(h.name) \(h.emoji). 🎊",
            "The \(o.name) \(o.emoji) glittered happily, and the \(p.name) \(p.emoji) felt warm and bright. 🌟",
            "Every creature in the \(p.name) \(p.emoji) clapped and cheered for the little \(h.name) \(h.emoji). 👏",
            "The \(h.name) \(h.emoji) took a bow, and the \(p.name) \(p.emoji) rang with happy laughter. 🥳",
        ]
    }

    private static func endings(_ h: StoryChoice, _ p: StoryChoice, _ m: StoryChoice) -> [String] {
        [
            "With a happy heart, the \(m.name) \(h.name) \(h.emoji) shared the magic with every friend. The End! 🎉",
            "And so the \(h.name) \(h.emoji) and all the friends celebrated together. The End! 🎉",
            "From that day on, the \(p.name) \(p.emoji) was the happiest place of all. The End! 🎉",
            "And the \(m.name) \(h.name) \(h.emoji) went home with the best story to tell. The End! 🎉",
            "Tucked in that night, the \(h.name) \(h.emoji) smiled, dreaming of new adventures. The End! 🌙",
            "Forever after, the \(h.name) \(h.emoji) and the \(p.name) \(p.emoji) were the best of friends. The End! 🎉",
            "The stars came out over the \(p.name) \(p.emoji), and the \(h.name) \(h.emoji) yawned a happy yawn. The End! 🌙",
            "And every story after that one started right here, in the \(p.name) \(p.emoji). The End! 📖",
        ]
    }

    /// Graft on the second fork: after the trouble is solved, what to do with the
    /// magic. A different *kind* of decision than the first, so it doesn't read as
    /// a repeat. Same ingredients, so it reads consistently — for four endings.
    static func withSecondFork(_ branch: StoryBranch,
                               h: StoryChoice, p: StoryChoice, o: StoryChoice, m: StoryChoice) -> StoryBranch {
        let twist = pick([
            "Just then, the \(o.name) \(o.emoji) began to glow — one last sparkle of magic was left inside!",
            "On the way home, the \(h.name) \(h.emoji) spotted a tiny door tucked into the \(p.name) \(p.emoji).",
            "Then the \(o.name) \(o.emoji) gave a soft hum, as if it had one more secret to share.",
            "As the sun dipped low, the \(p.name) \(p.emoji) filled with a warm golden glow.",
            "Just then, a friendly breeze carried a faraway giggle across the \(p.name) \(p.emoji).",
            "Suddenly the \(o.name) \(o.emoji) felt warm, and a little map shimmered across the \(p.name) \(p.emoji).",
        ])
        let celebration = celebrations(h, p, o)
        let ending = endings(h, p, m)

        return StoryBranch(
            emoji: branch.emoji,
            label: branch.label,
            pages: branch.pages,
            problem: "\(twist)\nWhat should the \(h.name) \(h.emoji) do now?",
            // Branch A — be generous with the magic.
            choiceA: StoryBranch(
                emoji: "🎁",
                label: "Share the magic",
                pages: [
                    pick([
                        "\"This belongs to all of us!\" said the \(h.name) \(h.emoji), passing the \(o.name) \(o.emoji) around the \(p.name) \(p.emoji). 💛",
                        "The \(m.name) \(h.name) \(h.emoji) shared the last of the magic, and every friend got a little sparkle of their own. 💛",
                        "One by one, the \(h.name) \(h.emoji) gave everyone a turn with the \(o.name) \(o.emoji). 💛",
                    ]),
                    pick(celebration),
                    pick(ending),
                ]),
            // Branch B — keep the adventure going.
            choiceB: StoryBranch(
                emoji: "🗺️",
                label: "Go exploring",
                pages: [
                    pick([
                        "The \(h.name) \(h.emoji) held the \(o.name) \(o.emoji) high and set off to see what else the \(p.name) \(p.emoji) was hiding! 🗺️",
                        "Off went the \(m.name) \(h.name) \(h.emoji), following the glow to a secret corner of the \(p.name) \(p.emoji). 🗺️",
                        "\"Let's find out!\" cheered the \(h.name) \(h.emoji), and the whole \(p.name) \(p.emoji) came along. 🗺️",
                    ]),
                    pick(celebration),
                    pick(ending),
                ]),
        )
    }

    static func buildStory(hero h: StoryChoice, place p: StoryChoice,
                           object o: StoryChoice, mood m: StoryChoice) -> Story {
        let opening = pick([
            "Once upon a time, \(an(m.name)) \(m.name) \(h.name) \(h.emoji) lived near \(an(p.name)) \(p.name) \(p.emoji).",
            "Long ago, in a faraway \(p.name) \(p.emoji), there lived a \(m.name) little \(h.name) \(h.emoji).",
            "Every morning, \(an(m.name)) \(m.name) \(h.name) \(h.emoji) woke up right beside \(an(p.name)) \(p.name) \(p.emoji).",
            "In a cozy corner of the \(p.name) \(p.emoji), \(an(m.name)) \(m.name) \(h.name) \(h.emoji) was just waking up.",
            "There once was \(an(m.name)) \(m.name) \(h.name) \(h.emoji) who loved the \(p.name) \(p.emoji) more than anywhere else.",
            "Far past the clouds, \(an(m.name)) \(m.name) \(h.name) \(h.emoji) made a home by \(an(p.name)) \(p.name) \(p.emoji).",
            "Where the sun rose over \(an(p.name)) \(p.name) \(p.emoji), \(an(m.name)) \(m.name) \(h.name) \(h.emoji) was humming a little tune.",
            "Nobody in the \(p.name) \(p.emoji) was quite as \(m.name) as one small \(h.name) \(h.emoji).",
        ])
        let discovery = pick([
            "One sunny day, the \(h.name) found \(an(o.name)) \(o.name) \(o.emoji) hidden in the tall grass!",
            "While exploring the \(p.name), the \(h.name) \(h.emoji) spotted \(an(o.name)) \(o.name) \(o.emoji)!",
            "Then, with a twinkle, \(an(o.name)) \(o.name) \(o.emoji) appeared right in front of the \(h.name)!",
            "As the \(h.name) \(h.emoji) skipped along, a shiny \(o.name) \(o.emoji) caught the light!",
            "Tucked under an old tree, the \(h.name) \(h.emoji) discovered \(an(o.name)) \(o.name) \(o.emoji).",
            "What's this? The \(h.name) \(h.emoji) had never seen \(an(o.name)) \(o.name) \(o.emoji) quite like it before.",
            "Something sparkled in the shadows — \(an(o.name)) \(o.name) \(o.emoji), waiting to be found!",
            "Right there, half-buried in the \(p.name) \(p.emoji), lay \(an(o.name)) \(o.name) \(o.emoji).",
        ])
        let journey = pick([
            "The \(m.name) \(h.name) \(h.emoji) tucked the \(o.name) \(o.emoji) away and set off deep into the \(p.name) \(p.emoji).",
            "Step by step, the \(h.name) \(h.emoji) wandered further into the \(p.name) \(p.emoji), the \(o.name) \(o.emoji) glowing softly.",
            "Full of wonder, the \(h.name) \(h.emoji) explored every winding corner of the \(p.name) \(p.emoji).",
            "Holding the \(o.name) \(o.emoji) close, the \(h.name) \(h.emoji) marched bravely on through the \(p.name) \(p.emoji).",
            "The \(o.name) \(o.emoji) seemed to point the way, so the \(h.name) \(h.emoji) followed it across the \(p.name) \(p.emoji).",
            "Humming a happy tune, the \(m.name) \(h.name) \(h.emoji) skipped deeper into the \(p.name) \(p.emoji).",
            "With the \(o.name) \(o.emoji) safe in hand, the \(h.name) \(h.emoji) tiptoed where nobody had been before.",
            "The \(p.name) \(p.emoji) stretched out wide, and the \(m.name) \(h.name) \(h.emoji) could not wait to see it all.",
        ])
        let trouble = pick([
            "But then — uh oh! A grumpy troll stomped across the \(p.name) \(p.emoji) and blocked the way.",
            "Suddenly a big storm cloud rolled over the \(p.name) \(p.emoji), and everything went dark.",
            "Just then, a tiny lost cub began to cry at the edge of the \(p.name) \(p.emoji).",
            "Oh no! A wobbly old bridge over the \(p.name) \(p.emoji) began to creak and sway.",
            "All at once, a thick fog rolled across the \(p.name) \(p.emoji) and hid the path.",
            "Then a sleepy giant snored so loudly that the whole \(p.name) \(p.emoji) shook!",
            "Uh oh — a tangle of vines had grown right across the \(p.name) \(p.emoji) overnight.",
            "Just then, a little bird flapped down, too tired to fly home across the \(p.name) \(p.emoji).",
        ])
        let problem = "\(trouble)\nWhat should the \(m.name) \(h.name) \(h.emoji) do?"

        // Branch A — be clever and use the magic item.
        let useItem = StoryBranch(
            emoji: o.emoji,
            label: "Use the \(o.name)",
            pages: [
                pick([
                    "The \(h.name) \(h.emoji) held up the \(o.name) \(o.emoji). With a bright flash of magic, the trouble melted away! ✨",
                    "Quick as a wink, the \(h.name) \(h.emoji) waved the \(o.name) \(o.emoji) — and poof! the problem was gone. ✨",
                    "The clever \(h.name) \(h.emoji) pointed the \(o.name) \(o.emoji) just right, and everything turned out perfectly! ✨",
                    "One gentle tap of the \(o.name) \(o.emoji), and the \(p.name) \(p.emoji) was safe and sound again. ✨",
                ]),
            ])
        // Branch B — be kind and call friends for help.
        let callFriends = StoryBranch(
            emoji: "🤝",
            label: "Call for friends",
            pages: [
                pick([
                    "The \(h.name) \(h.emoji) called out for help. Friends came running, and together they fixed everything in no time! 🤝",
                    "The \(h.name) \(h.emoji) whistled, and kind friends arrived to lend a hand. Together, they sorted it out! 🤝",
                    "With a big friendly shout, the \(h.name) \(h.emoji) gathered everyone, and as a team they made it all okay! 🤝",
                    "\"Together!\" cheered the \(h.name) \(h.emoji) — and every friend in the \(p.name) \(p.emoji) pitched in. 🤝",
                ]),
            ])

        return Story(
            pre: [opening, discovery, journey],
            problem: problem,
            choiceA: withSecondFork(useItem, h: h, p: p, o: o, m: m),
            choiceB: withSecondFork(callFriends, h: h, p: p, o: o, m: m))
    }

    /// Flatten the story along the path chosen so far. The tale forks up to twice,
    /// so the page list grows as the child decides.
    static func buildTimeline(story: Story, chosen: [StoryBranch]) -> StoryTimeline {
        var pages: [String] = story.pre
        pages.append(story.problem)
        var forks: [Int] = [story.pre.count]
        for b in chosen {
            pages.append(contentsOf: b.pages)
            if let problem = b.problem, b.choiceA != nil, b.choiceB != nil {
                pages.append(problem)
                forks.append(pages.count - 1)
            }
        }
        return StoryTimeline(pages: pages, forks: forks)
    }

    /// Pages still to come if the child keeps picking A — used only to show a
    /// total. Both branches are the same length in generated stories, so this is
    /// exact here (it was an estimate on Android, where an AI story could differ).
    static func remaining(from node: (any StoryForkNode)?) -> Int {
        guard let b = node?.forkChoiceA else { return 0 }
        let nested = (b.problem != nil && b.choiceA != nil && b.choiceB != nil) ? 1 + remaining(from: b) : 0
        return b.pages.count + nested
    }
}
