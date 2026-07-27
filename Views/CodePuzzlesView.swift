import SwiftUI

// MARK: - Pure engine (mirror of the Android CodePuzzlesEngine)

/// A single robot move.
enum CodeStep: String, CaseIterable, Sendable {
    case up = "↑", down = "↓", left = "←", right = "→"
}

/// One program instruction — either a single move or a Scratch-style repeat
/// loop. Loops hold a flat body of moves (no nesting) repeated 2–4 times.
enum CodeInstr: Sendable {
    case move(CodeStep)
    case loop(body: [CodeStep], times: Int)

    /// How many robot moves this instruction expands to.
    var moveCount: Int {
        switch self {
        case .move: return 1
        case .loop(let body, let times): return body.count * times
        }
    }
}

struct CodeLevel: Sendable {
    let size: Int
    let start: (Int, Int)
    let goal: (Int, Int)
    let walls: Set<[Int]>
    let maxMoves: Int

    /// One step from `from`; off-grid or wall moves stay put.
    func step(from: (Int, Int), dir: CodeStep) -> (Int, Int) {
        var (x, y) = from
        switch dir {
        case .up: y += 1
        case .down: y -= 1
        case .left: x -= 1
        case .right: x += 1
        }
        guard x >= 0, x < size, y >= 0, y < size, !walls.contains([x, y]) else { return from }
        return (x, y)
    }
}

extension Array where Element == CodeInstr {
    var moveCount: Int { reduce(0) { $0 + $1.moveCount } }

    /// Flattens loops into the raw move sequence the robot will walk.
    var expanded: [CodeStep] {
        flatMap { instr -> [CodeStep] in
            switch instr {
            case .move(let s): return [s]
            case .loop(let body, let times): return (0..<times).flatMap { _ in body }
            }
        }
    }
}

/// Persists which levels a kid has cleared (bucket `code.levels`), so the
/// level map can chain-unlock. Mirrors the Android `ai4kids.levels.v1` store.
@MainActor
enum CodeLevelStore {
    private static let key = "ai4kids.levels.v1"

    static func cleared(bucket: String = "code.levels") -> Set<Int> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else { return [] }
        return Set(map[bucket] ?? [])
    }

    static func markCleared(_ level: Int, bucket: String = "code.levels") {
        var map: [String: [Int]] = [:]
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            map = decoded
        }
        var set = Set(map[bucket] ?? [])
        set.insert(level)
        map[bucket] = set.sorted()
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - View

/// Code Puzzles — plan a path of arrows (and Scratch-style repeat loops!) that
/// walks the robot 🤖 to the goal ⭐️, then run it. A failed run keeps the plan
/// so kids can debug and try again.
struct CodePuzzlesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    private static let levels: [CodeLevel] = [
        CodeLevel(size: 4, start: (0, 0), goal: (3, 0), walls: [], maxMoves: 6),
        CodeLevel(size: 4, start: (0, 3), goal: (3, 0), walls: [[2, 2], [2, 1]], maxMoves: 10),
        CodeLevel(size: 5, start: (0, 0), goal: (4, 4), walls: [[2, 2], [3, 2], [1, 3]], maxMoves: 14),
    ]

    @State private var levelIndex: Int? = nil
    @State private var cleared: Set<Int> = []
    @State private var program: [CodeInstr] = []
    @State private var openLoop: [CodeStep]? = nil
    @State private var loopTimes = 2
    @State private var robot: (Int, Int) = (0, 0)
    @State private var running = false
    @State private var message = "Plan the robot's path to the star!"
    @State private var showCelebration = false

    private var level: CodeLevel { Self.levels[levelIndex ?? 0] }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let index = levelIndex {
                playView(index: index)
            } else {
                pickerView
            }
            if showCelebration {
                CelebrationView(message: "Solved it! 🤖⭐️")
                    .onTapGesture { nextLevel() }
            }
        }
        .onAppear { cleared = CodeLevelStore.cleared() }
    }

    // MARK: Level picker

    private var pickerView: some View {
        VStack(spacing: 28) {
            HStack {
                CloseButton { dismiss() }
                Spacer()
                Text("Code Puzzles").font(Theme.display(30)).foregroundStyle(Theme.ink)
                Spacer()
                StarBadge(count: progress.stars(for: .code))
            }
            Text("Pick a puzzle! Clear one to unlock the next.")
                .font(Theme.rounded(20, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
            HStack(spacing: 20) {
                ForEach(Self.levels.indices, id: \.self) { i in
                    levelChip(i)
                }
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private func isUnlocked(_ i: Int) -> Bool { i == 0 || cleared.contains(i - 1) }

    private func levelChip(_ i: Int) -> some View {
        let done = cleared.contains(i)
        let unlocked = isUnlocked(i)
        return Button {
            guard unlocked else { return }
            levelIndex = i
            resetLevel()
        } label: {
            VStack(spacing: 6) {
                if unlocked {
                    Text("\(i + 1)").font(Theme.display(34)).foregroundStyle(.white)
                    if done { Image(systemName: "star.fill").foregroundStyle(Theme.yellow) }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 92, height: 92)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(done ? Theme.green : unlocked ? Theme.blue : Theme.ink.opacity(0.3)))
            .softShadow()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Play

    private func playView(index: Int) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    CloseButton { levelIndex = nil }
                    Spacer()
                    Text("Code Puzzles  •  Level \(index + 1)")
                        .font(Theme.display(24)).foregroundStyle(Theme.ink)
                    Spacer()
                    StarBadge(count: progress.stars(for: .code))
                }
                Text(message)
                    .font(Theme.rounded(20, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
                grid
                programBar
                controls
            }
            .padding(compact ? 18 : 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            ForEach((0..<level.size).reversed(), id: \.self) { y in
                HStack(spacing: 6) {
                    ForEach(0..<level.size, id: \.self) { x in
                        cell(x, y)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
        .softShadow()
    }

    private func cell(_ x: Int, _ y: Int) -> some View {
        let isRobot = robot == (x, y)
        let isGoal = level.goal == (x, y)
        let isWall = level.walls.contains([x, y])
        let side: CGFloat = compact ? 48 : 60
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isWall ? Theme.ink.opacity(0.8) : Theme.blue.opacity(0.12))
            if isGoal { Text("⭐️").font(.system(size: side * 0.6)) }
            if isRobot { Text("🤖").font(.system(size: side * 0.6)) }
        }
        .frame(width: side, height: side)
    }

    // MARK: Program bar

    private var programBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Steps \(projectedCount) / \(level.maxMoves)")
                .font(Theme.rounded(15, .bold))
                .foregroundStyle(Theme.ink.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if program.isEmpty && openLoop == nil {
                        Text("Your steps appear here →")
                            .font(Theme.rounded(16, .medium)).foregroundStyle(Theme.ink.opacity(0.4))
                    }
                    ForEach(Array(program.enumerated()), id: \.offset) { _, instr in
                        instrTile(instr, open: false)
                    }
                    if let body = openLoop {
                        instrTile(.loop(body: body, times: loopTimes), open: true)
                    }
                }
                .frame(minHeight: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .softShadow()
    }

    private var projectedCount: Int {
        program.moveCount + (openLoop.map { $0.count * loopTimes } ?? 0)
    }

    @ViewBuilder
    private func instrTile(_ instr: CodeInstr, open: Bool) -> some View {
        switch instr {
        case .move(let step):
            Text(step.rawValue)
                .font(Theme.rounded(26, .heavy)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.blue))
        case .loop(let body, let times):
            HStack(spacing: 4) {
                ForEach(Array(body.enumerated()), id: \.offset) { _, step in
                    Text(step.rawValue)
                        .font(Theme.rounded(22, .heavy)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.blue))
                }
                if body.isEmpty {
                    Text("…").font(Theme.rounded(22, .heavy)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
                Text("×\(times)")
                    .font(Theme.rounded(18, .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 6)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(open ? Theme.orange : Theme.purple))
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(CodeStep.allCases, id: \.self) { step in
                    Button { addStep(step) } label: {
                        Text(step.rawValue)
                            .font(Theme.rounded(compact ? 26 : 32, .heavy)).foregroundStyle(.white)
                            .frame(width: compact ? 54 : 66, height: compact ? 54 : 66)
                            .background(Circle().fill(Theme.blue)).softShadow()
                    }.buttonStyle(.plain)
                }
            }
            if openLoop != nil {
                HStack(spacing: 10) {
                    ForEach([2, 3, 4], id: \.self) { n in
                        Button { loopTimes = n } label: {
                            Text("×\(n)")
                                .font(Theme.rounded(20, .heavy))
                                .foregroundStyle(loopTimes == n ? .white : Theme.orange)
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .background(Capsule().fill(loopTimes == n ? Theme.orange : Theme.orange.opacity(0.15)))
                        }.buttonStyle(.plain)
                    }
                    KidButton(title: "Done", systemImage: "checkmark", color: Theme.orange) { commitLoop() }
                }
            }
            HStack(spacing: 12) {
                if openLoop == nil {
                    KidButton(title: "Repeat", systemImage: "arrow.2.squarepath", color: Theme.purple) {
                        guard !running else { return }
                        openLoop = []
                        loopTimes = 2
                    }
                }
                KidButton(title: "Undo", systemImage: "arrow.uturn.backward", color: Theme.ink.opacity(0.5)) { undo() }
                KidButton(title: "Run", systemImage: "play.fill", color: Theme.green) { run() }
            }
        }
    }

    private func addStep(_ step: CodeStep) {
        guard !running else { return }
        let projected: Int
        if let body = openLoop {
            projected = program.moveCount + (body.count + 1) * loopTimes
        } else {
            projected = program.moveCount + 1
        }
        guard projected <= level.maxMoves else {
            message = "You cannot add any more steps!"
            return
        }
        if openLoop != nil {
            openLoop?.append(step)
        } else {
            program.append(.move(step))
        }
    }

    private func commitLoop() {
        guard let body = openLoop else { return }
        if !body.isEmpty {
            program.append(.loop(body: body, times: loopTimes))
        }
        openLoop = nil
    }

    private func undo() {
        guard !running else { return }
        if openLoop != nil {
            if openLoop!.isEmpty {
                openLoop = nil
            } else {
                openLoop?.removeLast()
            }
        } else if !program.isEmpty {
            program.removeLast()
        }
    }

    private func resetLevel() {
        program = []
        openLoop = nil
        loopTimes = 2
        robot = level.start
        running = false
        message = "Plan the robot's path to the star!"
    }

    private func run() {
        guard !running, !program.isEmpty else { return }
        guard openLoop == nil else {
            message = "Tap Done to finish your loop first."
            return
        }
        running = true
        robot = level.start
        var steps = program.expanded
        func tick() {
            guard !steps.isEmpty else { finishRun(); return }
            let step = steps.removeFirst()
            robot = level.step(from: robot, dir: step)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) { tick() }
            }
        }
        tick()
    }

    private func finishRun() {
        running = false
        if robot == level.goal {
            progress.award(2, to: .code)
            if let index = levelIndex {
                CodeLevelStore.markCleared(index)
                cleared.insert(index)
            }
            withAnimation { showCelebration = true }
        } else {
            // Keep the plan so kids can tweak and debug, like real programmers.
            message = "Almost! Tweak your steps and Run again. 🔁"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) { robot = level.start }
            }
        }
    }

    private func nextLevel() {
        showCelebration = false
        if let index = levelIndex, index + 1 < Self.levels.count {
            levelIndex = index + 1
            resetLevel()
        } else {
            levelIndex = nil
        }
    }
}
