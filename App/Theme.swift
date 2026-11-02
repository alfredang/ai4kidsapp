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
    static let purple = Color(red: 0.525, green: 0.325, blue: 0.643)
    static let pink = Color(red: 0.71, green: 0.235, blue: 0.447)
    static let orange = Color(red: 0.69, green: 0.475, blue: 0.208)
    static let yellow = Color(red: 1.0, green: 0.855, blue: 0.439)
    static let green = Color(red: 0.22, green: 0.525, blue: 0.424)
    static let blue = Color(red: 0.263, green: 0.557, blue: 0.682)
    static let teal = Color(red: 0.192, green: 0.529, blue: 0.49)
    static let red = Color(red: 0.749, green: 0.302, blue: 0.455)

    static let ink = Color(red: 0.314, green: 0.365, blue: 0.529)
    static let cardCornerRadius: CGFloat = 28
    static let bigCornerRadius: CGFloat = 36

    /// Soft, friendly drop shadow used on cards and buttons.
    static let softShadow = ShadowStyle(color: Color(red: 0.72, green: 0.65, blue: 0.83).opacity(0.35), radius: 0, x: 3, y: 5)

    /// The app-wide warm background gradient.
    static var background: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.929, green: 0.969, blue: 1.0),
                     Color(red: 0.957, green: 0.937, blue: 1.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rounded, chunky display font for headings.
    static func display(_ size: CGFloat) -> Font {
        .custom("AIKidsDisplay-Bold", size: size, relativeTo: .title)
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(weight == .regular || weight == .medium ? "AIKidsBody-Regular" : "AIKidsBody-Bold", size: size, relativeTo: .body)
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
        compositingGroup().shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Wraps content in the standard rounded white "play card" surface.
    func kidCard(cornerRadius: CGFloat = Theme.cardCornerRadius) -> some View {
        self
            .background(
                UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius - 4, bottomTrailingRadius: cornerRadius + 4, topTrailingRadius: cornerRadius - 8)
                    .fill(.white))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius - 4, bottomTrailingRadius: cornerRadius + 4, topTrailingRadius: cornerRadius - 8).stroke(Theme.purple.opacity(0.45), lineWidth: 2))
            .softShadow()
    }
}
