import SwiftUI

/// One of the five on-device learning activities offered on the home screen.
/// All content runs fully offline — no login, no network, no data collection.
enum Activity: String, CaseIterable, Identifiable, Sendable {
    case phonics
    case story
    case buddy
    case code
    case brain

    var id: String { rawValue }

    /// Display title shown on the home card.
    var title: String {
        switch self {
        case .phonics: return "Phonics Quest"
        case .story:   return "Story Builder"
        case .buddy:   return "Talking Buddy"
        case .code:    return "Code Puzzles"
        case .brain:   return "Brain Arcade"
        }
    }

    /// One-line, kid-readable description.
    var subtitle: String {
        switch self {
        case .phonics: return "Explore the sound worlds"
        case .story:   return "Make your own story"
        case .buddy:   return "Chat with your robot pal"
        case .code:    return "Solve coding puzzles"
        case .brain:   return "8 quick card games"
        }
    }

    /// SF Symbol shown on the card.
    var symbol: String {
        switch self {
        case .phonics: return "textformat.abc"
        case .story:   return "books.vertical.fill"
        case .buddy:   return "face.smiling.inverse"
        case .code:    return "puzzlepiece.fill"
        case .brain:   return "gamecontroller.fill"
        }
    }

    /// Card accent color.
    var color: Color {
        switch self {
        case .phonics: return Theme.pink
        case .story:   return Theme.orange
        case .buddy:   return Theme.teal
        case .code:    return Theme.blue
        case .brain:   return Theme.green
        }
    }

    /// Recommended age band (shown as a small tag).
    var ageBand: String {
        switch self {
        case .phonics: return "Ages 4–6"
        case .story:   return "Ages 7–9"
        case .buddy:   return "Ages 5–10"
        case .code:    return "Ages 10–12"
        case .brain:   return "All ages"
        }
    }
}
