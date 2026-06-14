import SwiftUI

/// One of the four on-device learning activities offered on the home screen.
/// All content runs fully offline — no login, no network, no data collection.
enum Activity: String, CaseIterable, Identifiable, Sendable {
    case phonics
    case story
    case code
    case brain

    var id: String { rawValue }

    /// Display title shown on the home card.
    var title: String {
        switch self {
        case .phonics: return "Phonics Playground"
        case .story:   return "Story Builder"
        case .code:    return "Code Puzzles"
        case .brain:   return "Brain Games"
        }
    }

    /// One-line, kid-readable description.
    var subtitle: String {
        switch self {
        case .phonics: return "Match letters & sounds"
        case .story:   return "Make your own story"
        case .code:    return "Solve coding puzzles"
        case .brain:   return "Memory & matching fun"
        }
    }

    /// SF Symbol shown on the card.
    var symbol: String {
        switch self {
        case .phonics: return "textformat.abc"
        case .story:   return "books.vertical.fill"
        case .code:    return "puzzlepiece.fill"
        case .brain:   return "brain.head.profile"
        }
    }

    /// Card accent color.
    var color: Color {
        switch self {
        case .phonics: return Theme.pink
        case .story:   return Theme.orange
        case .code:    return Theme.blue
        case .brain:   return Theme.green
        }
    }

    /// Recommended age band (shown as a small tag).
    var ageBand: String {
        switch self {
        case .phonics: return "Ages 4–6"
        case .story:   return "Ages 7–9"
        case .code:    return "Ages 10–12"
        case .brain:   return "All ages"
        }
    }
}
