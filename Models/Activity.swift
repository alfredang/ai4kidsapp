import SwiftUI

/// One of the seven on-device learning activities offered on the home screen.
/// All content runs fully offline — no login, no network, no data collection.
enum Activity: String, CaseIterable, Identifiable, Sendable {
    case phonics
    case story
    case code
    case escape
    case art
    case buddy
    case brain

    var id: String { rawValue }

    /// Display title shown on the home card.
    var title: String {
        switch self {
        case .phonics: return "Phonics Quest"
        case .story:   return "Story Builder"
        case .code:    return "Code Puzzles"
        case .escape:  return "Escape Room"
        case .art:     return "Art Studio"
        case .buddy:   return "Talking Buddy"
        case .brain:   return "Brain Arcade"
        }
    }

    /// One-line, kid-readable description.
    var subtitle: String {
        switch self {
        case .phonics: return "Explore the sound worlds"
        case .story:   return "Make your own story"
        case .code:    return "Solve coding puzzles"
        case .escape:  return "Walk, solve & escape!"
        case .art:     return "Make a picture, then puzzle it"
        case .buddy:   return "Chat with your robot pal"
        case .brain:   return "8 quick card games"
        }
    }

    /// SF Symbol shown on the card.
    var symbol: String {
        switch self {
        case .phonics: return "textformat.abc"
        case .story:   return "books.vertical.fill"
        case .code:    return "puzzlepiece.fill"
        case .escape:  return "door.left.hand.open"
        case .art:     return "paintbrush.fill"
        case .buddy:   return "face.smiling.inverse"
        case .brain:   return "gamecontroller.fill"
        }
    }

    /// Card accent color.
    var color: Color {
        switch self {
        case .phonics: return Theme.pink
        case .story:   return Theme.orange
        case .code:    return Theme.blue
        case .escape:  return Theme.purple
        case .art:     return Theme.red
        case .buddy:   return Theme.teal
        case .brain:   return Theme.green
        }
    }

    /// Recommended age band (shown as a small tag).
    var ageBand: String {
        switch self {
        case .phonics: return "Ages 4–6"
        case .story:   return "Ages 7–9"
        case .code:    return "Ages 7–12"
        case .escape:  return "Ages 7–12"
        case .art:     return "Ages 5–12"
        case .buddy:   return "Ages 5–10"
        case .brain:   return "All ages"
        }
    }
}
