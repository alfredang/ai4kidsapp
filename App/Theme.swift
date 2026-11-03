import SwiftUI

/// Runtime device classification for per-platform UI tweaks.
@MainActor
enum DeviceKind {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

/// Shared, kid-friendly visual styling tokens. Bright, rounded, high-contrast —
/// tuned for young learners (ages 4–16) on iPad.
enum Theme {
    // Brand palette — matches the family website (ai4kids.tertiarycourses.com.sg)
    static let purple = Color(hex: 0x80549F)
    static let plum = Color(hex: 0x99499B)
    static let pink = Color(red: 0.71, green: 0.235, blue: 0.447)
    static let orange = Color(red: 0.69, green: 0.475, blue: 0.208)
    static let yellow = Color(hex: 0xFFDC69)
    static let green = Color(red: 0.22, green: 0.525, blue: 0.424)
    static let blue = Color(red: 0.263, green: 0.557, blue: 0.682)
    static let teal = Color(hex: 0x268081)
    static let red = Color(red: 0.749, green: 0.302, blue: 0.455)

    static let ink = Color(hex: 0x41467D)
    static let cream = Color(hex: 0xFFF8EE)
    static let card = Color(hex: 0xFFFEFA)
    static let inputBorder = Color(hex: 0xC5B6DA)
    static let cardCornerRadius: CGFloat = 28
    static let bigCornerRadius: CGFloat = 36

    /// Soft, friendly drop shadow used on cards and buttons.
    static let softShadow = ShadowStyle(color: Color(hex: 0x41467D).opacity(0.22), radius: 0, x: 0, y: 4)

    /// The app-wide warm cream background gradient.
    static var background: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFFF8EE), Color(hex: 0xFFF3DC)],
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
                    .fill(Theme.card))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius - 4, bottomTrailingRadius: cornerRadius + 4, topTrailingRadius: cornerRadius - 8).stroke(Theme.ink.opacity(0.35), lineWidth: 2))
            .softShadow()
    }
}

extension Color {
    /// Builds an opaque colour from a 0xRRGGBB literal (website hex tokens).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
