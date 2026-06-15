import SwiftUI

/// Code Puzzles — a tiny "sequence the steps" game that teaches algorithmic
/// thinking without real code execution. The child taps direction arrows to plan
/// a path that walks the robot 🤖 to the goal ⭐️ on a small grid, then runs it.
struct CodePuzzlesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    private enum Step: String, CaseIterable { case up = "↑", down = "↓", left = "←", right = "→" }
    private struct Level { let size: Int; let start: (Int, Int); let goal: (Int, Int); let walls: Set<[Int]> }

    private static let levels: [Level] = [
        Level(size: 4, start: (0, 0), goal: (3, 0), walls: []),
        Level(size: 4, start: (0, 3), goal: (3, 0), walls: [[2, 2], [2, 1]]),
        Level(size: 5, start: (0, 0), goal: (4, 4), walls: [[2, 2], [3, 2], [1, 3]]),
    ]

    @State private var levelIndex = 0
    @State private var program: [Step] = []
    @State private var robot: (Int, Int) = (0, 0)
    @State private var running = false
    @State private var message = "Plan the robot's path to the star!"
    @State private var showCelebration = false

    private var level: Level { Self.levels[levelIndex] }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                topBar
                Text(message)
                    .font(Theme.rounded(22, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
                grid
                programBar
                controls
            }
            .padding(28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)

            if showCelebration {
                CelebrationView(message: "Solved it! 🤖⭐️")
                    .onTapGesture { nextLevel() }
            }
        }
        .onAppear(perform: resetLevel)
    }

    private var topBar: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Code Puzzles  •  Level \(levelIndex + 1)").font(Theme.display(24)).foregroundStyle(Theme.ink)
            Spacer()
            StarBadge(count: progress.stars(for: .code))
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
        let side: CGFloat = compact ? 52 : 64
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isWall ? Theme.ink.opacity(0.8) : Theme.blue.opacity(0.12))
            if isGoal { Text("⭐️").font(.system(size: side * 0.6)) }
            if isRobot { Text("🤖").font(.system(size: side * 0.6)) }
        }
        .frame(width: side, height: side)
    }

    private var programBar: some View {
        HStack(spacing: 8) {
            if program.isEmpty {
                Text("Your steps appear here →")
                    .font(Theme.rounded(16, .medium)).foregroundStyle(Theme.ink.opacity(0.4))
            }
            ForEach(Array(program.enumerated()), id: \.offset) { _, step in
                Text(step.rawValue)
                    .font(Theme.rounded(26, .heavy)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.blue))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .softShadow()
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ForEach(Step.allCases, id: \.self) { step in
                    Button { if !running { program.append(step) } } label: {
                        Text(step.rawValue)
                            .font(Theme.rounded(compact ? 28 : 34, .heavy)).foregroundStyle(.white)
                            .frame(width: compact ? 58 : 70, height: compact ? 58 : 70)
                            .background(Circle().fill(Theme.blue)).softShadow()
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                KidButton(title: "Undo", systemImage: "arrow.uturn.backward", color: Theme.ink.opacity(0.5)) {
                    if !running && !program.isEmpty { program.removeLast() }
                }
                KidButton(title: "Run", systemImage: "play.fill", color: Theme.green) { run() }
            }
        }
    }

    private func resetLevel() {
        program = []
        robot = level.start
        running = false
        message = "Plan the robot's path to the star!"
    }

    private func run() {
        guard !running, !program.isEmpty else { return }
        running = true
        robot = level.start
        var steps = program
        func tick() {
            guard !steps.isEmpty else { finishRun(); return }
            let step = steps.removeFirst()
            var (x, y) = robot
            switch step {
            case .up: y += 1
            case .down: y -= 1
            case .left: x -= 1
            case .right: x += 1
            }
            // Clamp to grid and respect walls (illegal move = stay put).
            if x >= 0, x < level.size, y >= 0, y < level.size, !level.walls.contains([x, y]) {
                robot = (x, y)
            }
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
            withAnimation { showCelebration = true }
        } else {
            message = "Almost! Try a new plan. 🔁"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { resetLevel() }
        }
    }

    private func nextLevel() {
        showCelebration = false
        levelIndex = (levelIndex + 1) % Self.levels.count
        resetLevel()
    }
}
