import SwiftUI

/// Art Studio — the child composes a colourful picture from built-in scenes
/// (fully offline — the Android app paints with cloud AI; here the pictures are
/// rendered on-device), then turns it into a tap-to-place jigsaw puzzle.
/// Difficulties mirror Android's `JigsawBoard`: 3×3 → 2★, 4×4 → 3★, 5×5 → 5★.
struct ArtStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    @State private var scene: ArtScene? = nil
    @State private var picture: UIImage? = nil
    @State private var puzzling = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let picture, puzzling {
                JigsawBoardView(picture: picture, compact: compact,
                                onExit: { puzzling = false },
                                onSolved: { stars in progress.award(stars, to: .art) })
            } else if let scene, let picture {
                previewView(scene: scene, picture: picture)
            } else {
                galleryView
            }
        }
    }

    // MARK: Gallery

    private var galleryView: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                    Text("Art Studio").font(Theme.display(30)).foregroundStyle(Theme.ink)
                    Spacer()
                    StarBadge(count: progress.stars(for: .art))
                }
                Text("Pick a picture to make, then turn it into a puzzle! 🧩")
                    .font(Theme.rounded(20, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 150 : 200), spacing: 16)],
                          spacing: 16) {
                    ForEach(ArtScene.all) { s in
                        Button { makePicture(s) } label: {
                            VStack(spacing: 8) {
                                ArtSceneCanvas(scene: s)
                                    .frame(height: compact ? 110 : 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                Text(s.title)
                                    .font(Theme.rounded(17, .heavy))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(10)
                            .kidCard(cornerRadius: 22)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(compact ? 18 : 28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func makePicture(_ s: ArtScene) {
        let renderer = ImageRenderer(content: ArtSceneCanvas(scene: s).frame(width: 600, height: 600))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        scene = s
        picture = image
    }

    // MARK: Preview

    private func previewView(scene: ArtScene, picture: UIImage) -> some View {
        VStack(spacing: 24) {
            HStack {
                CloseButton { self.scene = nil; self.picture = nil }
                Spacer()
                Text(scene.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                Spacer()
                StarBadge(count: progress.stars(for: .art))
            }
            Image(uiImage: picture)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 460)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                .softShadow()
            KidButton(title: "Play a puzzle 🧩", color: Theme.purple) { puzzling = true }
            KidButton(title: "Pick another picture", systemImage: "photo.on.rectangle.angled",
                      color: Theme.ink.opacity(0.5)) {
                self.scene = nil
                self.picture = nil
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scenes

/// A bundled picture the child can "make" — a bright gradient plus a big emoji
/// composition, rendered on-device (no network, no AI).
struct ArtScene: Identifiable, Sendable {
    let id: String
    let title: String
    let top: Color
    let bottom: Color
    let sky: [String]     // small accents scattered high
    let heroes: [String]  // the big characters
    let ground: String    // repeated along the bottom

    static let all: [ArtScene] = [
        ArtScene(id: "space", title: "Space Rocket", top: Color(red: 0.10, green: 0.10, blue: 0.30),
                 bottom: Color(red: 0.35, green: 0.20, blue: 0.55),
                 sky: ["⭐️", "✨", "🪐", "🌟"], heroes: ["🚀", "👩‍🚀"], ground: "🌑"),
        ArtScene(id: "sea", title: "Under the Sea", top: Color(red: 0.25, green: 0.70, blue: 0.90),
                 bottom: Color(red: 0.05, green: 0.35, blue: 0.60),
                 sky: ["🫧", "🐟", "🐠", "🫧"], heroes: ["🐙", "🐬"], ground: "🪸"),
        ArtScene(id: "dino", title: "Dino Park", top: Color(red: 0.55, green: 0.85, blue: 0.95),
                 bottom: Color(red: 0.25, green: 0.60, blue: 0.35),
                 sky: ["☁️", "🦋", "☀️", "☁️"], heroes: ["🦕", "🦖"], ground: "🌴"),
        ArtScene(id: "castle", title: "Fairy Castle", top: Color(red: 0.95, green: 0.75, blue: 0.90),
                 bottom: Color(red: 0.60, green: 0.45, blue: 0.85),
                 sky: ["🌈", "✨", "🦋", "☁️"], heroes: ["🏰", "🦄"], ground: "🌷"),
        ArtScene(id: "jungle", title: "Jungle Friends", top: Color(red: 0.75, green: 0.90, blue: 0.60),
                 bottom: Color(red: 0.15, green: 0.45, blue: 0.25),
                 sky: ["🦜", "🍃", "☀️", "🦋"], heroes: ["🦁", "🐵"], ground: "🌳"),
        ArtScene(id: "snow", title: "Snow Day", top: Color(red: 0.75, green: 0.85, blue: 0.98),
                 bottom: Color(red: 0.90, green: 0.95, blue: 1.0),
                 sky: ["❄️", "☁️", "❄️", "✨"], heroes: ["⛄️", "🐧"], ground: "🏔️"),
        ArtScene(id: "farm", title: "Farm Morning", top: Color(red: 0.99, green: 0.85, blue: 0.55),
                 bottom: Color(red: 0.55, green: 0.75, blue: 0.35),
                 sky: ["☀️", "☁️", "🐦", "☁️"], heroes: ["🐮", "🐔"], ground: "🌻"),
        ArtScene(id: "robot", title: "Robot City", top: Color(red: 0.55, green: 0.65, blue: 0.95),
                 bottom: Color(red: 0.25, green: 0.30, blue: 0.55),
                 sky: ["✨", "🛸", "⭐️", "✨"], heroes: ["🤖", "🏙️"], ground: "🚗"),
    ]
}

/// Draws a scene as a square picture: gradient sky, scattered accents, two big
/// hero emoji, and a ground row.
struct ArtSceneCanvas: View {
    let scene: ArtScene

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [scene.top, scene.bottom],
                               startPoint: .top, endPoint: .bottom)
                ForEach(Array(scene.sky.enumerated()), id: \.offset) { i, e in
                    Text(e)
                        .font(.system(size: h * 0.11))
                        .position(x: w * [0.18, 0.5, 0.82, 0.33][i % 4],
                                  y: h * [0.14, 0.09, 0.18, 0.30][i % 4])
                }
                ForEach(Array(scene.heroes.enumerated()), id: \.offset) { i, e in
                    Text(e)
                        .font(.system(size: h * 0.30))
                        .position(x: w * (i == 0 ? 0.35 : 0.70),
                                  y: h * (i == 0 ? 0.55 : 0.62))
                }
                HStack(spacing: w * 0.06) {
                    ForEach(0..<4, id: \.self) { _ in
                        Text(scene.ground).font(.system(size: h * 0.13))
                    }
                }
                .position(x: w * 0.5, y: h * 0.90)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Jigsaw (port of Android JigsawBoard)

private struct JigsawDiff: Identifiable {
    let id: String
    let grid: Int
    let stars: Int
    static let all = [
        JigsawDiff(id: "Easy", grid: 3, stars: 2),
        JigsawDiff(id: "Medium", grid: 4, stars: 3),
        JigsawDiff(id: "Hard", grid: 5, stars: 5),
    ]
}

struct JigsawBoardView: View {
    let picture: UIImage
    let compact: Bool
    let onExit: () -> Void
    let onSolved: (Int) -> Void

    @State private var diff: JigsawDiff? = nil
    // board[slot] = piece index placed there (piece i belongs in slot i), nil = empty.
    @State private var board: [Int?] = []
    @State private var tray: [Int] = []
    // Selected piece: from the tray (position = tray index) or the board (slot).
    @State private var sel: (fromTray: Bool, position: Int)? = nil
    @State private var peeking = false
    @State private var solvedStars: Int? = nil

    var body: some View {
        Group {
            if let diff {
                puzzleView(diff)
            } else {
                diffPicker
            }
        }
    }

    private var diffPicker: some View {
        VStack(spacing: 24) {
            HStack {
                CloseButton { onExit() }
                Spacer()
                Text("Pick a puzzle size").font(Theme.display(28)).foregroundStyle(Theme.ink)
                Spacer()
                Color.clear.frame(width: 50, height: 50)
            }
            ForEach(JigsawDiff.all) { d in
                Button { start(d) } label: {
                    HStack {
                        Text(d.id).font(Theme.rounded(24, .heavy)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(d.grid)×\(d.grid)")
                            .font(Theme.rounded(20, .bold)).foregroundStyle(Theme.ink.opacity(0.5))
                        HStack(spacing: 2) {
                            ForEach(0..<d.stars, id: \.self) { _ in
                                Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
                            }
                        }
                    }
                    .padding(20)
                    .kidCard(cornerRadius: 22)
                }
                .buttonStyle(PressableStyle())
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private func start(_ d: JigsawDiff) {
        diff = d
        board = Array(repeating: nil, count: d.grid * d.grid)
        tray = Array(0..<(d.grid * d.grid)).shuffled()
        sel = nil
        solvedStars = nil
    }

    private func puzzleView(_ d: JigsawDiff) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    CloseButton { diff = nil }
                    Spacer()
                    Text("\(d.id) puzzle").font(Theme.display(26)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { peeking.toggle() } label: {
                        Image(systemName: peeking ? "eye.fill" : "eye")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(Circle().fill(.white))
                            .softShadow()
                    }
                    .buttonStyle(.plain)
                }
                boardView(d)
                if solvedStars == nil {
                    trayView(d)
                } else {
                    VStack(spacing: 14) {
                        Text("You solved it! +\(d.stars) ⭐️")
                            .font(Theme.display(30)).foregroundStyle(Theme.purple)
                        KidButton(title: "Play again 🔁", color: Theme.green) { diff = nil }
                    }
                }
            }
            .padding(compact ? 16 : 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func boardView(_ d: JigsawDiff) -> some View {
        GeometryReader { geo in
            let side = geo.size.width
            let tile = side / CGFloat(d.grid)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                ForEach(0..<(d.grid * d.grid), id: \.self) { slot in
                    let row = slot / d.grid, col = slot % d.grid
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.ink.opacity(0.06))
                        if let piece = board[slot] {
                            pieceImage(piece, grid: d.grid, size: tile)
                        }
                    }
                    .overlay {
                        if let sel, !sel.fromTray, sel.position == slot {
                            RoundedRectangle(cornerRadius: 6).stroke(Theme.pink, lineWidth: 3)
                        }
                    }
                    .frame(width: tile - 4, height: tile - 4)
                    .offset(x: CGFloat(col) * tile + 2, y: CGFloat(row) * tile + 2)
                    .onTapGesture { tapSlot(slot) }
                }
                if peeking {
                    Image(uiImage: picture)
                        .resizable()
                        .frame(width: side, height: side)
                        .opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
            .softShadow()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func trayView(_ d: JigsawDiff) -> some View {
        let tileSize: CGFloat = compact ? 56 : 68
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(tray.enumerated()), id: \.element) { index, piece in
                    pieceImage(piece, grid: d.grid, size: tileSize)
                        .frame(width: tileSize, height: tileSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if let sel, sel.fromTray, sel.position == index {
                                RoundedRectangle(cornerRadius: 8).stroke(Theme.pink, lineWidth: 3)
                            }
                        }
                        .onTapGesture { tapTray(index) }
                }
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .softShadow()
    }

    /// Piece `i` = the source picture cropped to its home cell, shown at `size`.
    private func pieceImage(_ piece: Int, grid: Int, size: CGFloat) -> some View {
        let row = piece / grid, col = piece % grid
        return Image(uiImage: picture)
            .resizable()
            .frame(width: size * CGFloat(grid), height: size * CGFloat(grid))
            .offset(x: -CGFloat(col) * size, y: -CGFloat(row) * size)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }

    // MARK: Tap-to-place logic (mirrors Android)

    private func tapTray(_ index: Int) {
        guard solvedStars == nil else { return }
        if let s = sel, s.fromTray, s.position == index {
            sel = nil
        } else {
            sel = (fromTray: true, position: index)
        }
    }

    private func tapSlot(_ slot: Int) {
        guard let d = diff, solvedStars == nil else { return }
        if let s = sel {
            let displaced = board[slot]
            if s.fromTray {
                let piece = tray[s.position]
                board[slot] = piece
                tray.remove(at: s.position)
                if let displaced { tray.append(displaced) }
            } else {
                guard s.position != slot, let piece = board[s.position] else { sel = nil; return }
                board[slot] = piece
                board[s.position] = displaced
            }
            sel = nil
            checkWin(d)
        } else if board[slot] != nil {
            sel = (fromTray: false, position: slot)
        }
    }

    private func checkWin(_ d: JigsawDiff) {
        guard tray.isEmpty, board.indices.allSatisfy({ board[$0] == $0 }) else { return }
        solvedStars = d.stars
        onSolved(d.stars)
    }
}
