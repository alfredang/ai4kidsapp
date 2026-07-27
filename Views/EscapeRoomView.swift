import SwiftUI

// Escape Room — a top-down "walk, solve & escape" game. SwiftUI port of the
// Android LibGDX escape game (solo play; fully offline). The child steers a
// little hero with a floating joystick, walks between rooms, opens each room's
// puzzle at its station, and unlocks the exit once everything is solved.

// MARK: - Game state

private let escapeWorldW: CGFloat = 480
private let escapeWorldH: CGFloat = 640
private let escapePlayerR: CGFloat = 20
private let escapeSpeed: CGFloat = 230        // points per second
private let escapeJoyRadius: CGFloat = 72
private let escapeInteractR: CGFloat = 80
private let escapeExitR: CGFloat = 52
private let escapeStarsForWin = 5

/// What the hero is carrying (one item at a time).
enum EscapeCarry: Equatable {
    case core(Int)
    case bottle(Int)
    case artefact(Int)
}

enum EscapeActionKind: Equatable {
    case use(String)        // open room's puzzle
    case view(String)       // reopen a solved puzzle
    case lockedStation(String, String)   // room id, reason
    case read
    case exit
    case exitLocked(String)
    case takeCore(Int)
    case takeBottle(Int)
    case takeArtefact(Int)
    case sealedArtefact(Int)
    case charge(Int)
    case power
    case place
    case wash
    case recycle
    case drop

    var label: String {
        switch self {
        case .use: return "USE"
        case .view: return "VIEW"
        case .lockedStation: return "LOCKED"
        case .read: return "READ"
        case .exit: return "EXIT"
        case .exitLocked: return "LOCKED"
        case .takeCore, .takeBottle, .takeArtefact: return "TAKE"
        case .sealedArtefact: return "SEALED"
        case .charge: return "CHARGE"
        case .power: return "POWER"
        case .place: return "PLACE"
        case .wash: return "WASH"
        case .recycle: return "RECYCLE"
        case .drop: return "DROP"
        }
    }
}

@MainActor @Observable
final class EscapeGame {
    let level: EscapeLevelDef
    var player: CGPoint
    var joyOrigin: CGPoint? = nil
    var joyVector: CGVector = .zero
    var solved: Set<String> = []
    var clues: [String] = []
    var carry: EscapeCarry? = nil
    var won = false
    var toast: String? = nil
    var activePuzzle: String? = nil   // room id
    var readingNote = false
    var wordSearchFound: Set<String> = []

    // Cores / artefacts
    var corePos: [CGPoint?] = []
    var charged: Set<Int> = []
    var delivered: Set<Int> = []
    // Bottles
    var bottlePos: [CGPoint?] = []
    var washed: Set<Int> = []
    var recycled: Set<Int> = []

    private var toastTask: Task<Void, Never>? = nil

    init(level: EscapeLevelDef) {
        self.level = level
        let spawnRect = Self.rect(for: level.room[level.spawn]!, level: level)
        player = CGPoint(x: spawnRect.midX, y: spawnRect.midY - 30)
        if !level.cores.isEmpty && !level.directDeliver {
            // Cores start on the core room's floor.
            let rect = Self.rect(for: level.room[level.coreRoom!]!, level: level)
            corePos = level.cores.indices.map { i in
                CGPoint(x: rect.minX + rect.width * (0.22 + 0.24 * CGFloat(i)),
                        y: rect.minY + rect.height * 0.45)
            }
        }
        if level.directDeliver {
            // Artefacts sit in their own galleries.
            corePos = level.cores.map { id in
                let rect = Self.rect(for: level.room[id]!, level: level)
                return CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.3)
            }
        }
        bottlePos = level.bottleHomes.map { id in
            let rect = Self.rect(for: level.room[id]!, level: level)
            let yFrac: CGFloat = id == level.sinkRoom ? 0.22 : 0.45
            return CGPoint(x: rect.midX, y: rect.minY + rect.height * yFrac)
        }
    }

    // MARK: Geometry

    static func rect(for room: EscapeRoomDef, level: EscapeLevelDef) -> CGRect {
        let cw = escapeWorldW / CGFloat(level.cols)
        let ch = escapeWorldH / CGFloat(level.rows)
        return CGRect(x: CGFloat(room.gx) * cw, y: CGFloat(room.gy) * ch,
                      width: CGFloat(room.gw) * cw, height: CGFloat(room.gh) * ch)
    }

    func rect(_ id: String) -> CGRect { Self.rect(for: level.room[id]!, level: level) }

    /// Doorway rects (one per connected pair), spanning the shared edge.
    @ObservationIgnored lazy var doorways: [CGRect] = level.doors.compactMap { pair in
        let a = rect(pair[0]), b = rect(pair[1])
        // Vertical shared edge?
        if abs(a.maxX - b.minX) < 0.5 || abs(b.maxX - a.minX) < 0.5 {
            let x = abs(a.maxX - b.minX) < 0.5 ? a.maxX : b.maxX
            let top = max(a.minY, b.minY), bottom = min(a.maxY, b.maxY)
            guard bottom > top else { return nil }
            let gap = min((bottom - top) * 0.7, 110)
            let mid = (top + bottom) / 2
            return CGRect(x: x - 26, y: mid - gap / 2, width: 52, height: gap)
        }
        // Horizontal shared edge
        if abs(a.maxY - b.minY) < 0.5 || abs(b.maxY - a.minY) < 0.5 {
            let y = abs(a.maxY - b.minY) < 0.5 ? a.maxY : b.maxY
            let left = max(a.minX, b.minX), right = min(a.maxX, b.maxX)
            guard right > left else { return nil }
            let gap = min((right - left) * 0.7, 110)
            let mid = (left + right) / 2
            return CGRect(x: mid - gap / 2, y: y - 26, width: gap, height: 52)
        }
        return nil
    }

    private func allowed(_ p: CGPoint) -> Bool {
        for room in level.rooms {
            if Self.rect(for: room, level: level).insetBy(dx: escapePlayerR + 5, dy: escapePlayerR + 5)
                .contains(p) { return true }
        }
        for door in doorways {
            let inset = door.width > door.height
                ? door.insetBy(dx: escapePlayerR * 0.6, dy: 4)
                : door.insetBy(dx: 4, dy: escapePlayerR * 0.6)
            if inset.contains(p) { return true }
        }
        return false
    }

    var currentRoom: EscapeRoomDef {
        level.rooms.first { Self.rect(for: $0, level: level).contains(player) }
            ?? level.room[level.spawn]!
    }

    // MARK: Movement

    func tick(dt: CGFloat) {
        guard !won, activePuzzle == nil, !readingNote else { return }
        let v = joyVector
        guard v.dx != 0 || v.dy != 0 else { return }
        let len = max(sqrt(v.dx * v.dx + v.dy * v.dy), 0.0001)
        let step = escapeSpeed * dt
        let dx = v.dx / len * step * min(len / escapeJoyRadius, 1)
        let dy = v.dy / len * step * min(len / escapeJoyRadius, 1)
        // Axis-independent moves so the hero slides along walls.
        let tryX = CGPoint(x: player.x + dx, y: player.y)
        if allowed(tryX) { player = tryX }
        let tryY = CGPoint(x: player.x, y: player.y + dy)
        if allowed(tryY) { player = tryY }
    }

    // MARK: Points of interest

    func stationPos(_ room: EscapeRoomDef) -> CGPoint {
        let r = Self.rect(for: room, level: level)
        return CGPoint(x: r.midX, y: r.midY + 8)
    }

    var exitPos: CGPoint {
        let r = rect(level.exit)
        return CGPoint(x: r.minX + r.width * 0.88, y: r.minY + r.height * 0.84)
    }

    var notePos: CGPoint? {
        guard let clueRoom = level.clueRoom else { return nil }
        let r = rect(clueRoom)
        return CGPoint(x: r.midX, y: r.minY + r.height * 0.72)
    }

    var sinkPos: CGPoint? {
        guard let sink = level.sinkRoom else { return nil }
        let r = rect(sink)
        return CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.84)
    }

    var recyclerPos: CGPoint? {
        guard let sink = level.sinkRoom else { return nil }
        let r = rect(sink)
        return CGPoint(x: r.minX + r.width * 0.76, y: r.minY + r.height * 0.82)
    }

    private func near(_ p: CGPoint?, _ radius: CGFloat) -> Bool {
        guard let p else { return false }
        return hypot(p.x - player.x, p.y - player.y) <= radius
    }

    // MARK: Locks & win

    func isStationLocked(_ room: EscapeRoomDef) -> String? {
        if room.id == level.suitRoom, !level.directDeliver, delivered.count < level.cores.count {
            return "Bring all \(level.cores.count) charged cores here first!"
        }
        if room.id == level.bottleGateRoom, recycled.count < bottlePos.count {
            return "Recycle all the bottles first!"
        }
        if let requires = room.requires, !solved.contains(requires) {
            return "It's locked — a code from another room opens it."
        }
        if !room.requiresAll.allSatisfy({ solved.contains($0) }) {
            return "Solve the other rooms first!"
        }
        return nil
    }

    var exitUnlocked: Bool {
        solved.count >= level.totalStations
            && (!level.directDeliver || delivered.count >= level.cores.count)
    }

    // MARK: The single context action

    var action: EscapeActionKind? {
        // Specific interactions first.
        if case .bottle(let i) = carry {
            if near(sinkPos, 72), !washed.contains(i) { return .wash }
            if near(recyclerPos, 72), washed.contains(i) { return .recycle }
        }
        if case .core(let i) = carry, !level.directDeliver {
            let chargerId = level.cores[i]
            if let charger = level.room[chargerId], near(stationPos(charger), escapeInteractR),
               currentRoom.id == chargerId, !charged.contains(i) {
                return solved.contains(chargerId) ? .charge(i)
                    : .lockedStation(chargerId, "Solve this charger's game first!")
            }
            if let suit = level.suitRoom, currentRoom.id == suit,
               near(stationPos(level.room[suit]!), escapeInteractR), charged.contains(i) {
                return .power
            }
        }
        if case .artefact = carry, let suit = level.suitRoom, currentRoom.id == suit,
           near(stationPos(level.room[suit]!), escapeInteractR) {
            return .place
        }
        // Pick things up.
        if carry == nil {
            for (i, pos) in corePos.enumerated() where near(pos, 64) {
                if level.directDeliver {
                    return solved.contains(level.cores[i]) ? .takeArtefact(i) : .sealedArtefact(i)
                }
                return .takeCore(i)
            }
            for (i, pos) in bottlePos.enumerated() where near(pos, 64) && !recycled.contains(i) {
                return .takeBottle(i)
            }
        }
        // Exit door.
        if near(exitPos, escapeExitR) {
            return exitUnlocked ? .exit : .exitLocked(lockedExitReason)
        }
        // Clue note.
        if near(notePos, 72) { return .read }
        // Room station.
        let room = currentRoom
        if room.puzzle != nil, near(stationPos(room), escapeInteractR) {
            if solved.contains(room.id) { return .view(room.id) }
            if let reason = isStationLocked(room) { return .lockedStation(room.id, reason) }
            return .use(room.id)
        }
        // Drop what you carry.
        if carry != nil { return .drop }
        return nil
    }

    private var lockedExitReason: String {
        if level.directDeliver && delivered.count < level.cores.count {
            return "Place all the artefacts in the Time Capsule first!"
        }
        return "Solve every room to unlock the exit!"
    }

    func perform() {
        guard let action else { return }
        switch action {
        case .use(let id), .view(let id):
            activePuzzle = id
        case .lockedStation(_, let reason):
            show(reason)
        case .read:
            readingNote = true
        case .exit:
            won = true
        case .exitLocked(let reason):
            show(reason)
        case .takeCore(let i):
            corePos[i] = nil
            carry = .core(i)
        case .takeArtefact(let i):
            corePos[i] = nil
            carry = .artefact(i)
        case .sealedArtefact:
            show("It's sealed! Solve this gallery's puzzle first.")
        case .takeBottle(let i):
            bottlePos[i] = nil
            carry = .bottle(i)
        case .charge(let i):
            charged.insert(i)
            show("Core charged! ⚡️ Carry it to the Suit.")
        case .power:
            if case .core(let i) = carry {
                delivered.insert(i)
                carry = nil
                show(delivered.count == level.cores.count
                     ? "All cores delivered! The Suit hums to life…"
                     : "Core delivered! \(delivered.count)/\(level.cores.count)")
            }
        case .place:
            if case .artefact(let i) = carry {
                delivered.insert(i)
                carry = nil
                show(delivered.count == level.cores.count
                     ? "The Time Capsule is complete! ✨"
                     : "Artefact placed in the Time Capsule!")
            }
        case .wash:
            if case .bottle(let i) = carry {
                washed.insert(i)
                show("Bottle washed! 🫧 Now recycle it.")
            }
        case .recycle:
            if case .bottle(let i) = carry {
                recycled.insert(i)
                carry = nil
                show(recycled.count == bottlePos.count
                     ? "All bottles recycled! ♻️"
                     : "Recycled! \(recycled.count)/\(bottlePos.count)")
            }
        case .drop:
            switch carry {
            case .core(let i): corePos[i] = CGPoint(x: player.x, y: player.y + 26)
            case .bottle(let i): bottlePos[i] = CGPoint(x: player.x, y: player.y + 26)
            case .artefact(let i): corePos[i] = CGPoint(x: player.x, y: player.y + 26)
            case nil: break
            }
            carry = nil
        }
    }

    func solve(_ roomId: String) {
        guard !solved.contains(roomId) else { return }
        solved.insert(roomId)
        if let clue = level.room[roomId]?.clue { clues.append(clue) }
    }

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}

// MARK: - Lobby + host view

struct EscapeRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    @State private var game: EscapeGame? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let game {
                EscapeGameView(game: game,
                               onExit: { self.game = nil },
                               onWin: {
                                   progress.award(escapeStarsForWin, to: .escape)
                               })
                .id(game.level.id)
            } else {
                lobby
            }
        }
        .onAppear {
            // Optional launch hook (`-escapeLevel robot-lab`) used to deep-link
            // straight into a level, e.g. for App Store screenshots.
            if let raw = UserDefaults.standard.string(forKey: "escapeLevel"),
               let level = EscapeContent.levels.first(where: { $0.id == raw }) {
                game = EscapeGame(level: level)
            }
        }
    }

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                    Text("Escape Room").font(Theme.display(30)).foregroundStyle(Theme.ink)
                    Spacer()
                    StarBadge(count: progress.stars(for: .escape))
                }
                Text("Pick a room, walk around with the joystick, solve every puzzle and escape!")
                    .font(Theme.rounded(19, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                ForEach(EscapeContent.levels) { level in
                    Button { game = EscapeGame(level: level) } label: {
                        HStack(spacing: 16) {
                            Text(level.emoji)
                                .font(.system(size: 40))
                                .frame(width: 72, height: 72)
                                .background(Circle().fill(level.accent.opacity(0.18)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.name)
                                    .font(Theme.rounded(23, .heavy)).foregroundStyle(Theme.ink)
                                Text(level.blurb)
                                    .font(Theme.rounded(16, .medium))
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(level.accent)
                        }
                        .padding(18)
                        .kidCard(cornerRadius: 24)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(compact ? 18 : 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - The game view

private struct EscapeGameView: View {
    @Bindable var game: EscapeGame
    let onExit: () -> Void
    let onWin: () -> Void

    @State private var awarded = false

    var body: some View {
        ZStack {
            game.level.bg.ignoresSafeArea()
            VStack(spacing: 8) {
                hud
                GeometryReader { geo in
                    let scale = min(geo.size.width / escapeWorldW, geo.size.height / escapeWorldH)
                    EscapeCanvas(game: game, scale: scale)
                        .frame(width: escapeWorldW * scale, height: escapeWorldH * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(joystick(scale: scale))
                }
                bottomBar
            }
            .padding(12)

            // Puzzle overlays
            if let roomId = game.activePuzzle, let room = game.level.room[roomId] {
                puzzleOverlay(room)
                    .transition(.opacity)
            }
            if game.readingNote {
                EscapeNoteView(art: game.level.clueArt, accent: game.level.accent) {
                    game.readingNote = false
                }
            }
            if game.won {
                winOverlay
            }
        }
        .task {
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let now = ContinuousClock.now
                let dt = CGFloat(Double((now - last).components.attoseconds) / 1e18)
                last = now
                game.tick(dt: min(dt, 0.05))
            }
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 6) {
            HStack {
                CloseButton { onExit() }
                Spacer()
                VStack(spacing: 2) {
                    Text(game.level.name)
                        .font(Theme.rounded(20, .heavy)).foregroundStyle(.white)
                    Text("\(game.solved.count)/\(game.level.totalStations) solved")
                        .font(Theme.rounded(14, .bold)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                actionButton
            }
            if !game.clues.isEmpty || game.level.sinkRoom != nil || game.level.directDeliver {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if game.level.sinkRoom != nil {
                            chip("Bottles recycled: \(game.recycled.count)/\(game.bottlePos.count) ♻️")
                        }
                        if game.level.directDeliver {
                            chip("Artefacts placed: \(game.delivered.count)/\(game.level.cores.count) 🏺")
                        }
                        ForEach(game.clues, id: \.self) { clue in chip("💡 " + clue) }
                    }
                }
            }
            if let toast = game.toast {
                Text(toast)
                    .font(Theme.rounded(16, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(Capsule().fill(Theme.yellow.opacity(0.95)))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.toast)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(Theme.rounded(14, .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 6).padding(.horizontal, 12)
            .background(Capsule().fill(.white.opacity(0.18)))
    }

    private var actionButton: some View {
        let action = game.action
        return Button { game.perform() } label: {
            Text(action?.label ?? "•")
                .font(Theme.rounded(17, .heavy))
                .foregroundStyle(.white)
                .frame(width: 84, height: 52)
                .background(Capsule().fill(action == nil
                    ? Color.white.opacity(0.15)
                    : game.level.accent))
        }
        .buttonStyle(PressableStyle())
        .disabled(action == nil)
    }

    private var bottomBar: some View {
        Text("Drag anywhere to walk 🕹️")
            .font(Theme.rounded(14, .semibold))
            .foregroundStyle(.white.opacity(0.55))
    }

    // MARK: Joystick

    private func joystick(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = CGPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
                if game.joyOrigin == nil { game.joyOrigin = start }
                let loc = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                var dx = loc.x - start.x, dy = loc.y - start.y
                let len = hypot(dx, dy)
                if len > escapeJoyRadius {
                    dx = dx / len * escapeJoyRadius
                    dy = dy / len * escapeJoyRadius
                }
                game.joyVector = CGVector(dx: dx, dy: dy)
            }
            .onEnded { _ in
                game.joyOrigin = nil
                game.joyVector = .zero
            }
    }

    // MARK: Puzzle routing

    @ViewBuilder
    private func puzzleOverlay(_ room: EscapeRoomDef) -> some View {
        let accent = game.level.accent
        let isSolved = game.solved.contains(room.id)
        let close = { game.activePuzzle = nil }
        let solve = { game.solve(room.id) }
        switch room.puzzle {
        case .numberLock(let code, let prompt, let iconField):
            EscapeNumberLockView(code: code, prompt: prompt, iconField: iconField, accent: accent,
                                 solved: isSolved, onSolved: solve, onClose: close)
        case .order(let heading, let steps):
            EscapeOrderView(heading: heading, steps: steps, accent: accent,
                            solved: isSolved, onSolved: solve, onClose: close)
        case .cipher(let legend, let answer):
            EscapeCipherView(legend: legend, answer: answer, accent: accent,
                             solved: isSolved, onSolved: solve, onClose: close)
        case .wordSearch(let words, let grid, let crossCol, let crossRow, let sources):
            EscapeWordSearchView(words: words, grid: grid, crossCol: crossCol, crossRow: crossRow,
                                 powered: sources.allSatisfy { game.solved.contains($0) },
                                 accent: accent, found: $game.wordSearchFound,
                                 onSolved: solve, onClose: close)
        case .mcq(let question, let options):
            EscapeMcqView(question: question, options: options, accent: accent,
                          solved: isSolved, onSolved: solve, onClose: close)
        case .circuit:
            EscapeCircuitView(accent: accent, solved: isSolved, onSolved: solve, onClose: close)
        case .fair(let animals, let total):
            EscapeFairView(animals: animals, total: total, accent: accent,
                           solved: isSolved, onSolved: solve, onClose: close)
        case .sortKind:
            EscapeSortView(accent: accent, solved: isSolved, onSolved: solve, onClose: close)
        case .maze:
            EscapeMazeView(accent: accent, solved: isSolved, onSolved: solve, onClose: close)
        case .unscramble(let words, let hints):
            EscapeUnscrambleView(words: words, hints: hints, accent: accent,
                                 solved: isSolved, onSolved: solve, onClose: close)
        case .crossword:
            EscapeCrosswordView(accent: accent, solved: isSolved, onSolved: solve, onClose: close)
        case .symbolLock(let word):
            EscapeSymbolLockView(word: word, accent: accent,
                                 solved: isSolved, onSolved: solve, onClose: close)
        case nil:
            EmptyView()
        }
    }

    // MARK: Win

    private var winOverlay: some View {
        ZStack {
            CelebrationView(message: "You escaped! +\(escapeStarsForWin) ⭐️")
        }
        .onAppear {
            guard !awarded else { return }
            awarded = true
            onWin()
        }
        .onTapGesture { onExit() }
    }
}

// MARK: - Canvas rendering

private struct EscapeCanvas: View {
    let game: EscapeGame
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: scale, y: scale)
            let level = game.level
            let current = game.currentRoom

            // Room floors
            for (i, room) in level.rooms.enumerated() {
                let rect = EscapeGame.rect(for: room, level: level)
                let base = Self.floorColor(i).blended(with: level.floorTint, fraction: 0.4)
                ctx.fill(Path(rect), with: .color(base))
                if room.id == current.id {
                    drawFloorPattern(ctx, rect: rect, kind: room.floorKind ?? level.floorKind)
                }
            }

            // Walls: dark border around each room, then punch doorway gaps.
            for room in level.rooms {
                let rect = EscapeGame.rect(for: room, level: level)
                ctx.stroke(Path(rect), with: .color(Color.black.opacity(0.75)), lineWidth: 8)
            }
            for door in game.doorways {
                let idx = game.level.rooms.firstIndex { EscapeGame.rect(for: $0, level: level).intersects(door) } ?? 0
                let base = Self.floorColor(idx).blended(with: level.floorTint, fraction: 0.4)
                ctx.fill(Path(roundedRect: door, cornerRadius: 4), with: .color(base))
            }

            // Decor + station + items in the current room; fog elsewhere.
            for room in level.rooms {
                let rect = EscapeGame.rect(for: room, level: level)
                if room.id == current.id {
                    drawRoomContents(ctx, room: room, rect: rect)
                } else {
                    ctx.fill(Path(rect), with: .color(Color(red: 0.05, green: 0.05, blue: 0.10).opacity(0.93)))
                }
            }

            // Room title
            let titleRect = EscapeGame.rect(for: current, level: level)
            ctx.draw(Text(current.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85)),
                     at: CGPoint(x: titleRect.midX, y: titleRect.minY + 18))

            // Player
            drawPlayer(ctx)

            // Joystick
            if let origin = game.joyOrigin {
                ctx.stroke(Path(ellipseIn: CGRect(x: origin.x - escapeJoyRadius, y: origin.y - escapeJoyRadius,
                                                  width: escapeJoyRadius * 2, height: escapeJoyRadius * 2)),
                           with: .color(.white.opacity(0.35)), lineWidth: 3)
                let knob = CGPoint(x: origin.x + game.joyVector.dx, y: origin.y + game.joyVector.dy)
                ctx.fill(Path(ellipseIn: CGRect(x: knob.x - 20, y: knob.y - 20, width: 40, height: 40)),
                         with: .color(.white.opacity(0.55)))
            }
        }
    }

    static func floorColor(_ i: Int) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.30, 0.34, 0.46), (0.34, 0.30, 0.48), (0.28, 0.42, 0.36),
            (0.40, 0.34, 0.30), (0.26, 0.36, 0.50), (0.30, 0.40, 0.42),
        ]
        let c = palette[i % palette.count]
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private func drawFloorPattern(_ ctx: GraphicsContext, rect: CGRect, kind: EscapeFloorKind) {
        var path = Path()
        switch kind {
        case .metal, .tile, .panel, .concrete, .stone:
            let step: CGFloat = kind == .tile ? 30 : kind == .panel ? 34 : 46
            var x = rect.minX + step
            while x < rect.maxX { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)); x += step }
            var y = rect.minY + step
            while y < rect.maxY { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)); y += step }
            ctx.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: 1.5)
        case .wood:
            var y = rect.minY + 15
            while y < rect.maxY { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)); y += 15 }
            ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.1, blue: 0.02).opacity(0.24)), lineWidth: 1.5)
        case .grass:
            ctx.fill(Path(rect), with: .color(Color(red: 0.22, green: 0.44, blue: 0.14).opacity(0.5)))
            for i in 0..<16 {
                let gx = rect.minX + rect.width * CGFloat((i * 37 % 100)) / 100
                let gy = rect.minY + rect.height * CGFloat((i * 61 % 100)) / 100
                ctx.draw(Text("🌿").font(.system(size: 12)), at: CGPoint(x: gx, y: gy))
            }
        }
    }

    private func drawRoomContents(_ ctx: GraphicsContext, room: EscapeRoomDef, rect: CGRect) {
        let level = game.level
        // Decor in opposite corners.
        if room.decor.count >= 1 {
            ctx.draw(Text(room.decor[0]).font(.system(size: 26)),
                     at: CGPoint(x: rect.minX + 30, y: rect.minY + 36))
        }
        if room.decor.count >= 2 {
            ctx.draw(Text(room.decor[1]).font(.system(size: 26)),
                     at: CGPoint(x: rect.maxX - 30, y: rect.maxY - 30))
        }
        // Station
        if room.puzzle != nil {
            let pos = game.stationPos(room)
            let isSolved = game.solved.contains(room.id)
            let locked = !isSolved && game.isStationLocked(room) != nil
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 24, y: pos.y - 24, width: 48, height: 48)),
                     with: .color(isSolved ? Theme.green : locked ? Color.gray : level.accent))
            ctx.draw(Text(isSolved ? "✓" : locked ? "🔒" : "?")
                        .font(.system(size: 24, weight: .heavy)).foregroundStyle(.white),
                     at: pos)
        }
        // Exit door
        if room.id == level.exit {
            let pos = game.exitPos
            ctx.draw(Text(game.exitUnlocked ? "🚪" : "🔒").font(.system(size: 40)), at: pos)
        }
        // Clue note
        if room.id == level.clueRoom, let pos = game.notePos {
            ctx.draw(Text("📜").font(.system(size: 30)), at: pos)
        }
        // Sink + recycler
        if room.id == level.sinkRoom {
            if let sink = game.sinkPos { ctx.draw(Text("🚰").font(.system(size: 34)), at: sink) }
            if let rec = game.recyclerPos { ctx.draw(Text("♻️").font(.system(size: 34)), at: rec) }
        }
        // Cores / artefacts on the floor
        for (i, pos) in game.corePos.enumerated() {
            guard let pos, rect.contains(pos) else { continue }
            if level.directDeliver {
                let sealed = !game.solved.contains(level.cores[i])
                ctx.draw(Text(level.artefactEmoji[i]).font(.system(size: 32))
                            .foregroundStyle(.white.opacity(sealed ? 0.4 : 1)), at: pos)
                if sealed {
                    ctx.stroke(Path(ellipseIn: CGRect(x: pos.x - 24, y: pos.y - 24, width: 48, height: 48)),
                               with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [5]))
                }
            } else {
                let color = Self.coreColor(i)
                let glow = game.charged.contains(i)
                ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 14, y: pos.y - 14, width: 28, height: 28)),
                         with: .color(color.opacity(glow ? 1 : 0.75)))
                if glow {
                    ctx.stroke(Path(ellipseIn: CGRect(x: pos.x - 20, y: pos.y - 20, width: 40, height: 40)),
                               with: .color(color), lineWidth: 3)
                }
            }
        }
        // Delivered artefacts shown in the capsule / suit room.
        if room.id == level.suitRoom, !game.delivered.isEmpty {
            let base = game.stationPos(room)
            for (slot, i) in game.delivered.sorted().enumerated() {
                let p = CGPoint(x: base.x - 40 + CGFloat(slot) * 40, y: base.y + 44)
                if level.directDeliver {
                    ctx.draw(Text(level.artefactEmoji[i]).font(.system(size: 26)), at: p)
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)),
                             with: .color(Self.coreColor(i)))
                }
            }
        }
        // Bottles
        for (i, pos) in game.bottlePos.enumerated() {
            guard let pos, rect.contains(pos), !game.recycled.contains(i) else { continue }
            ctx.draw(Text("🧴").font(.system(size: 28)), at: pos)
        }
    }

    static func coreColor(_ i: Int) -> Color {
        [Theme.yellow, Theme.blue, Theme.green][i % 3]
    }

    private func drawPlayer(_ ctx: GraphicsContext) {
        let p = game.player
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - escapePlayerR, y: p.y - escapePlayerR,
                                        width: escapePlayerR * 2, height: escapePlayerR * 2)),
                 with: .color(Color(red: 0.98, green: 0.80, blue: 0.16)))
        for dx in [-7.0, 7.0] {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x + dx - 3, y: p.y - 8, width: 6, height: 9)),
                     with: .color(Theme.ink))
        }
        // Carried item above the head.
        if let carry = game.carry {
            let above = CGPoint(x: p.x, y: p.y - escapePlayerR - 16)
            switch carry {
            case .core(let i):
                let color = Self.coreColor(i)
                ctx.fill(Path(ellipseIn: CGRect(x: above.x - 12, y: above.y - 12, width: 24, height: 24)),
                         with: .color(color))
                if game.charged.contains(i) {
                    ctx.stroke(Path(ellipseIn: CGRect(x: above.x - 17, y: above.y - 17, width: 34, height: 34)),
                               with: .color(color), lineWidth: 3)
                }
            case .bottle(let i):
                ctx.draw(Text(game.washed.contains(i) ? "🧴✨" : "🧴").font(.system(size: 24)), at: above)
            case .artefact(let i):
                ctx.draw(Text(game.level.artefactEmoji[i]).font(.system(size: 26)), at: above)
            }
        }
    }
}

private extension Color {
    /// Cheap linear blend in sRGB space (good enough for floor tints).
    func blended(with other: Color, fraction: CGFloat) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(red: ar + (br - ar) * fraction,
                     green: ag + (bg - ag) * fraction,
                     blue: ab + (bb - ab) * fraction)
    }
}
