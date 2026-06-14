import SwiftUI

/// Runtime device classification for per-platform UI tweaks.
@MainActor
enum DeviceKind {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

/// Shared, kid-friendly visual styling tokens. Bright, rounded, high-contrast —
/// tuned for young learners (ages 4–16) on iPad.
enum Theme {
    // Brand palette (AI4Kids — playful, saturated)
    static let purple = Color(red: 0.45, green: 0.30, blue: 0.92)
    static let pink   = Color(red: 0.98, green: 0.35, blue: 0.62)
    static let orange = Color(red: 1.00, green: 0.58, blue: 0.20)
    static let yellow = Color(red: 1.00, green: 0.80, blue: 0.16)
    static let green  = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let blue   = Color(red: 0.20, green: 0.62, blue: 0.98)
    static let teal   = Color(red: 0.12, green: 0.78, blue: 0.78)
    static let red    = Color(red: 0.96, green: 0.34, blue: 0.34)

    static let ink    = Color(red: 0.16, green: 0.14, blue: 0.30)
    static let cardCornerRadius: CGFloat = 28
    static let bigCornerRadius: CGFloat = 36

    /// Soft, friendly drop shadow used on cards and buttons.
    static let softShadow = ShadowStyle(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)

    /// The app-wide warm background gradient.
    static var background: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.96, green: 0.95, blue: 1.0),
                     Color(red: 1.0, green: 0.96, blue: 0.93)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rounded, chunky display font for headings.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    /// Applies the standard soft shadow used across cards and buttons.
    func softShadow(_ style: Theme.ShadowStyle = Theme.softShadow) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Wraps content in the standard rounded white "play card" surface.
    func kidCard(cornerRadius: CGFloat = Theme.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white))
            .softShadow()
    }
}
