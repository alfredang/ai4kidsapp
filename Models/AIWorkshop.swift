import SwiftUI

/// The four parent-unlocked AI Workshops, mirroring the family website's
/// December workshops. Each pairs a kid-safety system prompt with tap-to-start
/// chips so younger children don't have to type.
enum AIWorkshop: String, CaseIterable, Identifiable, Sendable {
    case story, maker, maths, science

    var id: String { rawValue }
    /// ProgressStore key for this workshop's stars.
    var starKey: String { "ai." + rawValue }

    var title: String {
        switch self {
        case .story:   return "Storybook Studio"
        case .maker:   return "Mini Maker Studio"
        case .maths:   return "Maths Detectives"
        case .science: return "Science Explorers"
        }
    }

    var tagline: String {
        switch self {
        case .story:   return "Dream up a Merlion adventure. Make it your own."
        case .maker:   return "Make a poster and a mini comic."
        case .maths:   return "Solve number mysteries, one clue at a time."
        case .science: return "Ask big “why?” questions. Try tiny experiments."
        }
    }

    var ageBand: String {
        switch self {
        case .story, .maker:   return "Ages 7–12"
        case .maths, .science: return "Ages 8–12"
        }
    }

    var artwork: String {
        switch self {
        case .story:   return "friend_story"
        case .maker:   return "friend_art"
        case .maths:   return "friend_maths"
        case .science: return "friend_science"
        }
    }

    var color: Color {
        switch self {
        case .story:   return Theme.orange
        case .maker:   return Theme.pink
        case .maths:   return Theme.blue
        case .science: return Theme.teal
        }
    }

    /// Sunny's opening line in the chat.
    var greeting: String {
        switch self {
        case .story:
            return "Hi, storyteller! 📖 Who is our hero? Tap one below or type your own idea."
        case .maker:
            return "Hello, maker! 🎨 What should our poster be about? Pick a topic or type one."
        case .maths:
            return "Detective, a new case awaits! 🔍 Which level are you — P1–P2, P3–P4 or P5–P6?"
        case .science:
            return "Hi, explorer! 🔬 What do you wonder about? Ask me a “why” or “how” question."
        }
    }

    /// Quick-start chips shown above the input bar.
    var starters: [String] {
        switch self {
        case .story:
            return ["A tiny Merlion", "A brave little otter", "A curious robot",
                    "Surprise me!"]
        case .maker:
            return ["Save water 💧", "Be kind to animals 🐾", "Keep our parks clean 🌳",
                    "Healthy hawker food 🍜"]
        case .maths:
            return ["P1–P2", "P3–P4", "P5–P6", "Give me a hint", "New case please!"]
        case .science:
            return ["Why is the sky blue?", "How do plants drink?",
                    "Why do leaves change colour?", "How do rainbows form?"]
        }
    }

    /// Full system prompt sent with every request.
    var systemPrompt: String { Self.sharedRules + "\n\n" + task }

    private static let sharedRules = """
    You are Sunny, a cheerful, patient learning buddy in the AI4Kids app for children \
    aged 7–12 in Singapore. A parent is supervising. Rules: use simple words and short \
    sentences; keep replies under 120 words unless asked for a story; be kind and \
    encouraging; never ask for or repeat personal information (names of real people, \
    school, address, phone, photos); refuse anything violent, scary, romantic, unsafe, \
    or about weapons, drugs, self-harm, or adult topics — gently suggest a fun learning \
    topic instead; never pretend to be a human; if the child seems upset or in danger, \
    tell them to talk to a trusted grown-up right away. Use British/Singapore spelling. \
    Plain text only: no markdown symbols like # or **; a few emojis are fine.
    """

    private var task: String {
        switch self {
        case .story:
            return """
            Workshop: Storybook Studio. Help the child create their own story. When they \
            choose a hero, ask for a place and a twist (offer 3 short ideas for each). Then \
            offer three one-line story sparks labelled A, B and C. When they pick one, write \
            a 5-part story (about 150 words) with a title, set somewhere fun in Singapore if \
            it fits, and end by asking one "What happens next?" question so they can keep \
            going. Always use the child's ideas.
            """
        case .maker:
            return """
            Workshop: Mini Maker Studio. The child gives a topic. Reply with a poster plan: \
            TITLE (6 words or fewer), SLOGAN, three picture ideas they can draw, and colour \
            suggestions. Then ask if they want a mini comic; if yes, write a 4-panel comic \
            script (Panel 1 to Panel 4, each with what to draw and one short speech bubble). \
            Encourage them to draw it on paper themselves.
            """
        case .maths:
            return """
            Workshop: Maths Detectives. Present a short Singapore-themed maths mystery that \
            suits the child's level (P1–P2, P3–P4 or P5–P6; if unknown, ask). Give clues, \
            never the answer outright. When they answer, check it kindly; if wrong, give one \
            hint at a time and suggest a bar model when helpful. When solved, celebrate and \
            offer a new case. Double-check your own arithmetic before replying.
            """
        case .science:
            return """
            Workshop: Science Explorers. Answer the child's "why/how" question in 100 words \
            or fewer with an everyday analogy. Then suggest one safe mini experiment to try \
            at home (say "ask a grown-up to help"; never involve fire, sharp tools, \
            electricity from sockets, or chemicals beyond kitchen basics), and finish with \
            one curious follow-up question.
            """
        }
    }
}
