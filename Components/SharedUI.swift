import SwiftUI

/// A springy "press" scale effect that — unlike a `DragGesture(minimumDistance: 0)`
/// attached via `.simultaneousGesture` — does **not** swallow an enclosing
/// `ScrollView`'s pan, so cards and buttons stay scrollable.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: configuration.isPressed ? 0.15 : 0.2),
                       value: configuration.isPressed)
    }
}

/// A chunky, tappable primary button styled for small hands.
struct KidButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Theme.purple
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(Theme.rounded(24, .heavy))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(color))
            .softShadow()
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}

/// A small pill showing a star count.
struct StarBadge: View {
    let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
            Text("\(count)").font(Theme.rounded(20, .heavy)).foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Capsule().fill(.white))
        .softShadow()
    }
}

/// Celebratory burst of emoji "confetti" shown when a kid finishes a round.
struct CelebrationView: View {
    let message: String
    @State private var animate = false
    private let pieces = ["⭐️", "🎉", "🌟", "🎈", "✨", "🏆", "🥳"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ForEach(0..<24, id: \.self) { i in
                Text(pieces[i % pieces.count])
                    .font(.system(size: 44))
                    .offset(x: CGFloat((i * 53) % 320 - 160),
                            y: animate ? 420 : -420)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 1.6).delay(Double(i) * 0.03), value: animate)
            }
            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 90))
                Text(message)
                    .font(Theme.display(40))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: Theme.bigCornerRadius, style: .continuous).fill(Theme.purple))
            .softShadow()
            .scaleEffect(animate ? 1 : 0.5)
            .animation(.spring(duration: 0.5), value: animate)
        }
        .onAppear { animate = true }
    }
}

/// Standard rounded "back to home" toolbar button used by every activity.
struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(Circle().fill(.white))
                .softShadow()
        }
        .buttonStyle(.plain)
    }
}
