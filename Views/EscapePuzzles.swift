import SwiftUI

// Escape Room puzzle overlays — SwiftUI ports of the Android game's puzzle
// canvas. Each puzzle calls `onSolved()` exactly once, then the child taps
// Close (or the game auto-dismisses).

// MARK: - Shared glyphs

/// The eight pictogram glyphs used by cipher / symbol-lock puzzles.
enum EscapeGlyph {
    static let symbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill",
                          "circle", "plus", "xmark", "star.fill"]
    static let colors: [Color] = [Theme.orange, Theme.blue, Theme.green, Theme.pink,
                                  Theme.purple, Theme.yellow, Color(red: 0.45, green: 0.52, blue: 0.65),
                                  Color(red: 0.95, green: 0.45, blue: 0.40)]

    static func view(_ index: Int, size: CGFloat = 26) -> some View {
        Image(systemName: symbols[index % 8])
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(colors[index % 8])
    }
}

// MARK: - Panel chrome

/// Rounded card panel every puzzle sits in, with a title bar and close button.
struct EscapePuzzlePanel<Content: View>: View {
    let title: String
    let accent: Color
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(Theme.rounded(22, .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(accent)
                ScrollView {
                    content
                        .padding(18)
                }
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .softShadow()
            .frame(maxWidth: 560, maxHeight: 640)
            .padding(20)
        }
    }
}

/// Green banner + close shown once a puzzle is done.
struct EscapeSolvedBanner: View {
    var message = "Solved! 🎉"
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(Theme.display(28)).foregroundStyle(Theme.green)
                .multilineTextAlignment(.center)
            KidButton(title: "Close", systemImage: "checkmark", color: Theme.green) { onClose() }
        }
        .padding(.top, 8)
    }
}

// MARK: - Number lock

struct EscapeNumberLockView: View {
    let code: String
    let prompt: String
    let iconField: [Int]?
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var entered = ""
    @State private var wrong = false
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: prompt, accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                if let field = iconField {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(Array(field.enumerated()), id: \.offset) { _, kind in
                            Group {
                                if kind == -1 {
                                    Text("🤖").font(.system(size: 34))
                                } else {
                                    EscapeGlyph.view(kind, size: 28)
                                }
                            }
                            .frame(height: 46)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.06)))
                        }
                    }
                }
                Text(entered.isEmpty ? " " : entered)
                    .font(Theme.display(34))
                    .foregroundStyle(wrong ? Theme.red : Theme.ink)
                    .frame(width: 200, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.08)))
                if wrong {
                    Text("Try again!").font(Theme.rounded(18, .bold)).foregroundStyle(Theme.red)
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                } else {
                    keypad
                }
            }
        }
        .onAppear { if solved { done = true } }
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(72)), count: 3), spacing: 12) {
            ForEach(keys, id: \.self) { key in
                Button { press(key) } label: {
                    Text(key)
                        .font(Theme.rounded(26, .heavy))
                        .foregroundStyle(key == "OK" ? Color.white : Theme.ink)
                        .frame(width: 72, height: 58)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(key == "OK" ? accent : Theme.ink.opacity(0.08)))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func press(_ key: String) {
        wrong = false
        switch key {
        case "⌫": if !entered.isEmpty { entered.removeLast() }
        case "OK":
            if entered == code {
                done = true
                onSolved()
            } else {
                wrong = true
                entered = ""
            }
        default:
            if entered.count < 6 { entered += key }
        }
    }
}

// MARK: - Order (sequence three steps)

struct EscapeOrderView: View {
    let heading: String
    let steps: [String]
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var display: [Int] = []
    @State private var picks: [Int] = []
    @State private var wrong = false
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: heading, accent: accent, onClose: onClose) {
            VStack(spacing: 12) {
                ForEach(Array(display.enumerated()), id: \.offset) { index, stepIndex in
                    let pickPos = picks.firstIndex(of: index)
                    Button { tap(index) } label: {
                        HStack {
                            ZStack {
                                Circle().fill(pickPos != nil ? accent : Theme.ink.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                if let pickPos {
                                    Text("\(pickPos + 1)")
                                        .font(Theme.rounded(18, .heavy)).foregroundStyle(.white)
                                }
                            }
                            Text(steps[stepIndex])
                                .font(Theme.rounded(18, .semibold))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(wrong ? Theme.red.opacity(0.12) : Theme.ink.opacity(0.05)))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(done || solved)
                }
                if wrong {
                    Text("Wrong order — try again!")
                        .font(Theme.rounded(18, .bold)).foregroundStyle(Theme.red)
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                }
            }
        }
        .onAppear {
            if solved { done = true }
            var order = Array(steps.indices)
            repeat { order.shuffle() } while order == Array(steps.indices)
            display = order
        }
    }

    private func tap(_ index: Int) {
        wrong = false
        if picks.contains(index) {
            picks = []
            return
        }
        picks.append(index)
        guard picks.count == steps.count else { return }
        if picks.map({ display[$0] }) == Array(steps.indices) {
            done = true
            onSolved()
        } else {
            wrong = true
            picks = []
        }
    }
}

// MARK: - Cipher

struct EscapeCipherView: View {
    let legend: String
    let answer: String
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var glyphOf: [Character: Int] = [:]
    @State private var typed = ""
    @State private var wrong = false
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: "Crack the symbol code!", accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(Array(legend), id: \.self) { letter in
                        HStack(spacing: 6) {
                            EscapeGlyph.view(glyphOf[letter] ?? 0, size: 20)
                            Text("= \(String(letter))")
                                .font(Theme.rounded(17, .heavy)).foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
                    }
                }
                Text("The message:")
                    .font(Theme.rounded(16, .semibold)).foregroundStyle(Theme.ink.opacity(0.6))
                HStack(spacing: 10) {
                    ForEach(Array(answer.enumerated()), id: \.offset) { _, letter in
                        EscapeGlyph.view(glyphOf[letter] ?? 0, size: 30)
                    }
                }
                .padding(.vertical, 10).padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.08)))
                Text(typed.isEmpty ? " " : typed)
                    .font(Theme.display(30))
                    .foregroundStyle(wrong ? Theme.red : Theme.ink)
                    .frame(minWidth: 180, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(Array(legend) + ["⌫"], id: \.self) { key in
                            Button { press(key) } label: {
                                Text(String(key))
                                    .font(Theme.rounded(22, .heavy)).foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.08)))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
            if solved { done = true }
            let indices = Array(0..<8).shuffled()
            for (i, letter) in legend.enumerated() { glyphOf[letter] = indices[i] }
        }
    }

    private func press(_ key: Character) {
        wrong = false
        if key == "⌫" {
            if !typed.isEmpty { typed.removeLast() }
            return
        }
        typed.append(key)
        guard typed.count == answer.count else { return }
        if typed == answer {
            done = true
            onSolved()
        } else {
            wrong = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { typed = ""; wrong = false }
        }
    }
}

// MARK: - Word search

struct EscapeWordSearchView: View {
    let words: [String]
    let grid: [String]
    let crossCol: Int
    let crossRow: Int
    /// Machines that must be solved before the display powers up.
    let powered: Bool
    let accent: Color
    @Binding var found: Set<String>
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var dragStart: (Int, Int)? = nil
    @State private var dragEnd: (Int, Int)? = nil
    @State private var cellSize: CGFloat = 34

    private var done: Bool { Set(words).isSubset(of: found) }

    var body: some View {
        EscapePuzzlePanel(title: powered ? "Find the hidden words!" : "Word Display", accent: accent,
                          onClose: onClose) {
            VStack(spacing: 14) {
                if !powered {
                    Text("The display is dark. Solve the three machines to power it up! 🔌")
                        .font(Theme.rounded(19, .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(Theme.rounded(16, .heavy))
                            .foregroundStyle(found.contains(word) ? .white : Theme.ink.opacity(powered ? 0.7 : 0.3))
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Capsule().fill(found.contains(word) ? Theme.green : Theme.ink.opacity(0.07)))
                    }
                }
                gridView
                if done {
                    EscapeSolvedBanner(
                        message: "They cross at Column \(crossCol + 1), Row \(crossRow + 1)!",
                        onClose: onClose)
                }
            }
        }
        .onChange(of: done) { _, isDone in if isDone { onSolved() } }
    }

    private var gridView: some View {
        let n = grid.count
        return GeometryReader { geo in
            let cell = geo.size.width / CGFloat(n)
            VStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { col in
                            let ch = Array(grid[row])[col]
                            let inFound = foundCells.contains([row, col])
                            let inDrag = dragCells.contains([row, col])
                            Text(powered ? String(ch) : "?")
                                .font(Theme.rounded(cell * 0.5, .heavy))
                                .foregroundStyle(powered ? (inFound || inDrag ? .white : Theme.ink) : Theme.ink.opacity(0.25))
                                .frame(width: cell, height: cell)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(inFound ? Theme.green : inDrag ? accent :
                                                powered ? Theme.ink.opacity(0.05) : Theme.ink.opacity(0.12))
                                        .padding(1))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(powered && !done ? dragGesture(cell: cell, n: n) : nil)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(cell: CGFloat, n: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let col = min(max(Int(value.location.x / cell), 0), n - 1)
                let row = min(max(Int(value.location.y / cell), 0), n - 1)
                if dragStart == nil { dragStart = (row, col) }
                dragEnd = (row, col)
            }
            .onEnded { _ in
                defer { dragStart = nil; dragEnd = nil }
                let cells = dragCells
                guard cells.count > 1 else { return }
                let word = cells.map { String(Array(grid[$0[0]])[$0[1]]) }.joined()
                for target in words where !found.contains(target) {
                    if word == target || word == String(target.reversed()) {
                        found.insert(target)
                    }
                }
            }
    }

    /// Cells along the current straight drag line (row / column / diagonal).
    private var dragCells: [[Int]] {
        guard let s = dragStart, let e = dragEnd else { return [] }
        let dr = e.0 - s.0, dc = e.1 - s.1
        guard dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return [[s.0, s.1]] }
        let steps = max(abs(dr), abs(dc))
        guard steps > 0 else { return [[s.0, s.1]] }
        let stepR = dr == 0 ? 0 : dr / abs(dr)
        let stepC = dc == 0 ? 0 : dc / abs(dc)
        return (0...steps).map { [s.0 + stepR * $0, s.1 + stepC * $0] }
    }

    /// Cells of every already-found word (recomputed by scanning the grid).
    private var foundCells: Set<[Int]> {
        var cells: Set<[Int]> = []
        let n = grid.count
        let chars = grid.map { Array($0) }
        let dirs = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for word in found {
            let letters = Array(word)
            for row in 0..<n {
                for col in 0..<n {
                    for (dr, dc) in dirs {
                        for reversed in [false, true] {
                            let target = reversed ? letters.reversed().map { $0 } : letters
                            let endR = row + dr * (target.count - 1)
                            let endC = col + dc * (target.count - 1)
                            guard endR >= 0, endR < n, endC >= 0, endC < n else { continue }
                            var match = true
                            for i in 0..<target.count where chars[row + dr * i][col + dc * i] != target[i] {
                                match = false
                                break
                            }
                            if match {
                                for i in 0..<target.count { cells.insert([row + dr * i, col + dc * i]) }
                            }
                        }
                    }
                }
            }
        }
        return cells
    }
}

// MARK: - MCQ

struct EscapeMcqView: View {
    let question: String
    let options: [String]   // options[0] is correct
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var display: [String] = []
    @State private var wrongPick: String? = nil
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: question, accent: accent, onClose: onClose) {
            VStack(spacing: 12) {
                ForEach(display, id: \.self) { option in
                    Button { pick(option) } label: {
                        Text(option)
                            .font(Theme.rounded(21, .heavy))
                            .foregroundStyle((done || solved) && option == options[0] ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill((done || solved) && option == options[0] ? Theme.green :
                                        wrongPick == option ? Theme.red.opacity(0.25) : Theme.ink.opacity(0.06)))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(done || solved)
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                }
            }
        }
        .onAppear {
            if solved { done = true }
            display = options.shuffled()
        }
    }

    private func pick(_ option: String) {
        if option == options[0] {
            done = true
            onSolved()
        } else {
            wrongPick = option
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { wrongPick = nil }
        }
    }
}

// MARK: - Circuit (rotate the pipes)

struct EscapeCircuitView: View {
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    // Direction bits: N=1, E=2, S=4, W=8. Source feeds cell (1,0) from the
    // west; the bulb at (1,2) lights through its east side.
    @State private var cells: [[Int]] = []
    @State private var done = false

    private static let n = 1, e = 2, s = 4, w = 8

    var body: some View {
        EscapePuzzlePanel(title: "Turn the pipes so power reaches the bulb!", accent: accent,
                          onClose: onClose) {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Text("⚡️").font(.system(size: 34))
                    pipeGrid
                    Text(poweredCells.contains([1, 2]) ? "💡" : "🔌").font(.system(size: 34))
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                }
            }
        }
        .onAppear {
            if solved { done = true }
            scramble()
        }
    }

    private var pipeGrid: some View {
        let lit = powered
        return VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        pipeCell(row: row, col: col, lit: lit.contains([row, col]))
                            .onTapGesture {
                                guard !done, !solved else { return }
                                cells[row][col] = Self.rotate(cells[row][col])
                                check()
                            }
                    }
                }
            }
        }
    }

    private func pipeCell(row: Int, col: Int, lit: Bool) -> some View {
        let bits = cells.isEmpty ? 0 : cells[row][col]
        return Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var path = Path()
            if bits & Self.n != 0 { path.move(to: c); path.addLine(to: CGPoint(x: c.x, y: 0)) }
            if bits & Self.s != 0 { path.move(to: c); path.addLine(to: CGPoint(x: c.x, y: size.height)) }
            if bits & Self.e != 0 { path.move(to: c); path.addLine(to: CGPoint(x: size.width, y: c.y)) }
            if bits & Self.w != 0 { path.move(to: c); path.addLine(to: CGPoint(x: 0, y: c.y)) }
            ctx.stroke(path, with: .color(lit ? Color.yellow : Color.gray.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 10, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)),
                     with: .color(lit ? Color.yellow : Color.gray))
        }
        .frame(width: 76, height: 76)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.08)))
    }

    private static func rotate(_ bits: Int) -> Int {
        // N→E, E→S, S→W, W→N
        var out = 0
        if bits & n != 0 { out |= e }
        if bits & e != 0 { out |= s }
        if bits & s != 0 { out |= w }
        if bits & w != 0 { out |= n }
        return out
    }

    private func scramble() {
        var grid = Array(repeating: Array(repeating: 0, count: 3), count: 3)
        // Solution path per the Android level.
        grid[1][0] = Self.w | Self.n
        grid[0][0] = Self.s | Self.e
        grid[0][1] = Self.w | Self.e
        grid[0][2] = Self.w | Self.s
        grid[1][2] = Self.n | Self.e
        let fillers = [Self.w | Self.e, Self.n | Self.s, Self.n | Self.e,
                       Self.s | Self.w, Self.e | Self.s, Self.n | Self.w]
        for (r, c) in [(1, 1), (2, 0), (2, 1), (2, 2)] {
            grid[r][c] = fillers.randomElement()!
        }
        repeat {
            for r in 0..<3 {
                for c in 0..<3 {
                    for _ in 0..<Int.random(in: 1...3) { grid[r][c] = Self.rotate(grid[r][c]) }
                }
            }
            cells = grid
        } while isSolvedNow && !solved
        if solved {
            // Review mode: show it solved.
            cells[1][0] = Self.w | Self.n
            cells[0][0] = Self.s | Self.e
            cells[0][1] = Self.w | Self.e
            cells[0][2] = Self.w | Self.s
            cells[1][2] = Self.n | Self.e
        }
    }

    /// Flood-fill from the source; returns lit cells.
    private var powered: Set<[Int]> { powersFrom() }
    private var poweredCells: Set<[Int]> { powered }

    private func powersFrom() -> Set<[Int]> {
        guard !cells.isEmpty else { return [] }
        var lit: Set<[Int]> = []
        // Source enters (1,0) through its west side.
        guard cells[1][0] & Self.w != 0 else { return [] }
        var queue: [[Int]] = [[1, 0]]
        lit.insert([1, 0])
        while let cell = queue.popLast() {
            let (r, c) = (cell[0], cell[1])
            let bits = cells[r][c]
            let neighbors: [(Int, Int, Int, Int)] = [
                (r - 1, c, Self.n, Self.s), (r + 1, c, Self.s, Self.n),
                (r, c + 1, Self.e, Self.w), (r, c - 1, Self.w, Self.e),
            ]
            for (nr, nc, out, into) in neighbors {
                guard nr >= 0, nr < 3, nc >= 0, nc < 3 else { continue }
                guard bits & out != 0, cells[nr][nc] & into != 0 else { continue }
                if lit.insert([nr, nc]).inserted { queue.append([nr, nc]) }
            }
        }
        return lit
    }

    private var isSolvedNow: Bool {
        powered.contains([1, 2]) && cells[1][2] & Self.e != 0
    }

    private func check() {
        if isSolvedNow {
            done = true
            onSolved()
        }
    }
}

// MARK: - Fair share

struct EscapeFairView: View {
    let animals: [String]
    let total: Int
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var counts: [Int] = []
    @State private var done = false

    private var given: Int { counts.reduce(0, +) }
    private var each: Int { total / max(animals.count, 1) }

    var body: some View {
        EscapePuzzlePanel(title: "Share \(total) treats fairly!", accent: accent, onClose: onClose) {
            VStack(spacing: 14) {
                Text("Treats left: \(max(total - given, 0)) 🍪")
                    .font(Theme.rounded(20, .heavy)).foregroundStyle(Theme.ink)
                ForEach(Array(animals.enumerated()), id: \.offset) { index, animal in
                    HStack(spacing: 16) {
                        Text(animal).font(.system(size: 40))
                        Spacer()
                        stepper(index, -1, "minus.circle.fill")
                        Text("\(counts.indices.contains(index) ? counts[index] : 0)")
                            .font(Theme.display(28)).foregroundStyle(Theme.ink)
                            .frame(width: 44)
                        stepper(index, +1, "plus.circle.fill")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.ink.opacity(0.05)))
                }
                if done || solved {
                    EscapeSolvedBanner(message: "Everyone gets \(each)! Fair and square 🎉", onClose: onClose)
                }
            }
        }
        .onAppear {
            if solved { done = true; counts = Array(repeating: each, count: animals.count) }
            else { counts = Array(repeating: 0, count: animals.count) }
        }
    }

    private func stepper(_ index: Int, _ delta: Int, _ symbol: String) -> some View {
        Button {
            guard !done, !solved else { return }
            let next = counts[index] + delta
            guard next >= 0, delta < 0 || given < total else { return }
            counts[index] = next
            if given == total, counts.allSatisfy({ $0 == each }) {
                done = true
                onSolved()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(accent)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Kind/Mean sort

struct EscapeSortView: View {
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var choices: [Bool?] = []
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: "Kind or mean? Sort the words!", accent: accent, onClose: onClose) {
            VStack(spacing: 12) {
                ForEach(Array(escapeKindnessItems.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("“\(item.0)”")
                            .font(Theme.rounded(18, .semibold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            choiceButton(index, true, "Kind 💚", item)
                            choiceButton(index, false, "Mean 💔", item)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(0.05)))
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                }
            }
        }
        .onAppear {
            if solved {
                done = true
                choices = escapeKindnessItems.map { $0.1 }
            } else {
                choices = Array(repeating: nil, count: escapeKindnessItems.count)
            }
        }
    }

    private func choiceButton(_ index: Int, _ value: Bool, _ label: String,
                              _ item: (String, Bool)) -> some View {
        let picked = choices.indices.contains(index) ? choices[index] == value : false
        return Button {
            guard !done, !solved else { return }
            choices[index] = value
            if zip(choices, escapeKindnessItems).allSatisfy({ $0 == $1.1 }) {
                done = true
                onSolved()
            }
        } label: {
            Text(label)
                .font(Theme.rounded(17, .heavy))
                .foregroundStyle(picked ? .white : Theme.ink.opacity(0.7))
                .padding(.vertical, 8).padding(.horizontal, 16)
                .background(Capsule().fill(picked ? (value ? Theme.green : Theme.red) : Theme.ink.opacity(0.08)))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Honesty maze

struct EscapeMazeView: View {
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var variant = escapeMazeVariants[0]
    @State private var hero: (Int, Int) = (1, 1)
    @State private var done = false
    @State private var signText: String? = nil

    var body: some View {
        EscapePuzzlePanel(title: "Torch-lit maze — walk the honest path!", accent: accent,
                          onClose: onClose) {
            VStack(spacing: 14) {
                mazeGrid
                if let signText {
                    Text("🪧 " + signText)
                        .font(Theme.rounded(16, .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.yellow.opacity(0.25)))
                }
                if done || solved {
                    EscapeSolvedBanner(message: "You found the honest way out! 🎉", onClose: onClose)
                } else {
                    dpad
                }
            }
        }
        .onAppear {
            if solved { done = true }
            variant = escapeMazeVariants.randomElement()!
            hero = find("S")
        }
    }

    private func find(_ ch: Character) -> (Int, Int) {
        for (r, row) in variant.rows.enumerated() {
            if let c = Array(row).firstIndex(of: ch) { return (r, c) }
        }
        return (1, 1)
    }

    private var mazeGrid: some View {
        let rows = variant.rows.map { Array($0) }
        return GeometryReader { geo in
            let cell = geo.size.width / 11
            VStack(spacing: 0) {
                ForEach(0..<11, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<11, id: \.self) { c in
                            let lit = done || solved || (abs(r - hero.0) <= 1 && abs(c - hero.1) <= 1)
                            let ch = rows[r][c]
                            ZStack {
                                Rectangle().fill(
                                    !lit ? Color(red: 0.07, green: 0.07, blue: 0.12) :
                                        ch == "#" ? Color(red: 0.30, green: 0.32, blue: 0.40) :
                                        Color(red: 0.92, green: 0.90, blue: 0.82))
                                if lit {
                                    if hero == (r, c) {
                                        Text("🦸").font(.system(size: cell * 0.7))
                                    } else if ch == "G" {
                                        Text("🚪").font(.system(size: cell * 0.7))
                                    } else if variant.signs.contains(where: { $0.row == r && $0.col == c }) {
                                        Text("🪧").font(.system(size: cell * 0.6))
                                    }
                                }
                            }
                            .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var dpad: some View {
        VStack(spacing: 8) {
            dpadButton("arrow.up", 0, -1)
            HStack(spacing: 40) {
                dpadButton("arrow.left", -1, 0)
                dpadButton("arrow.right", 1, 0)
            }
            dpadButton("arrow.down", 0, 1)
        }
    }

    private func dpadButton(_ symbol: String, _ dc: Int, _ dr: Int) -> some View {
        Button {
            move(dr: dr, dc: dc)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(accent))
        }
        .buttonStyle(PressableStyle())
    }

    private func move(dr: Int, dc: Int) {
        guard !done else { return }
        let r = hero.0 + dr, c = hero.1 + dc
        guard r >= 0, r < 11, c >= 0, c < 11 else { return }
        let rows = variant.rows.map { Array($0) }
        guard rows[r][c] != "#" else { return }
        hero = (r, c)
        signText = variant.signs.first { $0.row == r && $0.col == c }?.text
        if rows[r][c] == "G" {
            done = true
            onSolved()
        }
    }
}

// MARK: - Unscramble

struct EscapeUnscrambleView: View {
    let words: [String]
    let hints: [String]
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var wordIndex = 0
    @State private var tiles: [Character] = []
    @State private var filled: [Character] = []
    @State private var wrong = false
    @State private var done = false

    private var word: String { words[min(wordIndex, words.count - 1)] }

    var body: some View {
        EscapePuzzlePanel(title: "Unscramble the word!", accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                Text("Word \(min(wordIndex + 1, words.count)) of \(words.count)")
                    .font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink.opacity(0.5))
                if hints.indices.contains(wordIndex) && !(done || solved) {
                    Text("Clue: \(hints[wordIndex])")
                        .font(Theme.rounded(17, .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                // Slots
                HStack(spacing: 8) {
                    ForEach(0..<word.count, id: \.self) { i in
                        Text(i < filled.count ? String(filled[i]) : "")
                            .font(Theme.display(26))
                            .foregroundStyle(wrong ? Theme.red : Theme.ink)
                            .frame(width: 44, height: 50)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.ink.opacity(i < filled.count ? 0.12 : 0.05)))
                            .onTapGesture {
                                // Tap the last filled slot to undo.
                                if i == filled.count - 1, !done, !solved {
                                    tiles.append(filled.removeLast())
                                }
                            }
                    }
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(word.count, 6)),
                              spacing: 10) {
                        ForEach(Array(tiles.enumerated()), id: \.offset) { index, letter in
                            Button { place(index) } label: {
                                Text(String(letter))
                                    .font(Theme.rounded(24, .heavy)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
            if solved { done = true }
            loadWord()
        }
    }

    private func loadWord() {
        var shuffled = Array(word)
        if word.count > 1 {
            repeat { shuffled.shuffle() } while String(shuffled) == word
        }
        tiles = shuffled
        filled = []
        wrong = false
    }

    private func place(_ index: Int) {
        guard !done else { return }
        filled.append(tiles.remove(at: index))
        guard filled.count == word.count else { return }
        if String(filled) == word {
            if wordIndex + 1 < words.count {
                wordIndex += 1
                loadWord()
            } else {
                done = true
                onSolved()
            }
        } else {
            wrong = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { loadWord() }
        }
    }
}

// MARK: - Crossword

struct EscapeCrosswordView: View {
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var placed: [Int?] = []       // row index -> tray word index
    @State private var tray: [Int] = []          // word indices still in the tray
    @State private var selectedTray: Int? = nil
    @State private var done = false

    private let rows = escapeCrosswordRows

    var body: some View {
        EscapePuzzlePanel(title: "Place the words — the gold column spells a secret!",
                          accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        rowView(rowIndex, row)
                    }
                }
                if done || solved {
                    EscapeSolvedBanner(message: "The gold column spells LION! 🦁", onClose: onClose)
                } else {
                    Text("Tap a word, then tap a row.")
                        .font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.ink.opacity(0.5))
                    HStack(spacing: 10) {
                        ForEach(tray, id: \.self) { wordIndex in
                            Button {
                                selectedTray = selectedTray == wordIndex ? nil : wordIndex
                            } label: {
                                Text(rows[wordIndex].word)
                                    .font(Theme.rounded(17, .heavy))
                                    .foregroundStyle(selectedTray == wordIndex ? .white : Theme.ink)
                                    .padding(.vertical, 10).padding(.horizontal, 12)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedTray == wordIndex ? accent : Theme.ink.opacity(0.08)))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
            if solved {
                done = true
                placed = Array(rows.indices)
                tray = []
            } else {
                placed = Array(repeating: nil, count: rows.count)
                tray = Array(rows.indices).shuffled()
            }
        }
    }

    private func rowView(_ rowIndex: Int, _ row: (num: Int, word: String, offset: Int)) -> some View {
        let cell: CGFloat = 30
        let placedWord = placed.indices.contains(rowIndex) ? placed[rowIndex].map { rows[$0].word } : nil
        return HStack(spacing: 3) {
            Text("\(row.num)")
                .font(Theme.rounded(15, .heavy)).foregroundStyle(Theme.ink.opacity(0.5))
                .frame(width: 18)
            ForEach(0..<12, id: \.self) { col in
                let letterIndex = col - row.offset
                let inWord = letterIndex >= 0 && letterIndex < row.word.count
                let isSecret = col == escapeCrosswordSecretCol
                if inWord {
                    Text(placedWord.map { letterIndex < $0.count ? String(Array($0)[letterIndex]) : "" } ?? "")
                        .font(Theme.rounded(16, .heavy))
                        .foregroundStyle(placedWord == row.word ? Theme.green : Theme.ink)
                        .frame(width: cell, height: cell)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(isSecret ? Theme.yellow.opacity(0.45) : Theme.ink.opacity(0.07)))
                } else {
                    Color.clear.frame(width: cell, height: cell)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapRow(rowIndex) }
    }

    private func tapRow(_ rowIndex: Int) {
        guard !done, !solved else { return }
        if let sel = selectedTray {
            // Place; return any displaced word to the tray.
            if let displaced = placed[rowIndex] { tray.append(displaced) }
            placed[rowIndex] = sel
            tray.removeAll { $0 == sel }
            selectedTray = nil
            if placed.enumerated().allSatisfy({ $0.element == $0.offset }) {
                done = true
                onSolved()
            }
        } else if let existing = placed[rowIndex] {
            placed[rowIndex] = nil
            tray.append(existing)
        }
    }
}

// MARK: - Symbol lock

struct EscapeSymbolLockView: View {
    let word: String
    let accent: Color
    let solved: Bool
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var glyphOf: [Character: Int] = [:]
    @State private var palette: [Int] = []
    @State private var entered: [Int] = []
    @State private var wrong = false
    @State private var done = false

    var body: some View {
        EscapePuzzlePanel(title: "Spell \(word) in symbols!", accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                // The key
                HStack(spacing: 14) {
                    ForEach(Array(word), id: \.self) { letter in
                        HStack(spacing: 4) {
                            Text(String(letter))
                                .font(Theme.rounded(20, .heavy)).foregroundStyle(Theme.ink)
                            Text("=").foregroundStyle(Theme.ink.opacity(0.4))
                            EscapeGlyph.view(glyphOf[letter] ?? 0, size: 20)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
                    }
                }
                // Entered so far
                HStack(spacing: 10) {
                    ForEach(0..<word.count, id: \.self) { i in
                        Group {
                            if i < entered.count {
                                EscapeGlyph.view(entered[i], size: 26)
                            } else {
                                Text("·").font(Theme.display(26)).foregroundStyle(Theme.ink.opacity(0.3))
                            }
                        }
                        .frame(width: 44, height: 50)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(wrong ? Theme.red.opacity(0.15) : Theme.ink.opacity(0.06)))
                    }
                }
                if done || solved {
                    EscapeSolvedBanner(onClose: onClose)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(palette, id: \.self) { glyph in
                            Button { press(glyph) } label: {
                                EscapeGlyph.view(glyph, size: 28)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.07)))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    KidButton(title: "Undo", systemImage: "arrow.uturn.backward",
                              color: Theme.ink.opacity(0.5)) {
                        if !entered.isEmpty { entered.removeLast() }
                    }
                }
            }
        }
        .onAppear {
            if solved { done = true }
            let indices = Array(0..<8).shuffled()
            for (i, letter) in word.enumerated() { glyphOf[letter] = indices[i] }
            let used = word.map { glyphOf[$0]! }
            let decoys = indices.filter { !used.contains($0) }.prefix(3)
            palette = (used + decoys).shuffled()
        }
    }

    private func press(_ glyph: Int) {
        wrong = false
        entered.append(glyph)
        guard entered.count == word.count else { return }
        if entered == word.map({ glyphOf[$0]! }) {
            done = true
            onSolved()
        } else {
            wrong = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { entered = []; wrong = false }
        }
    }
}

// MARK: - Clue note

struct EscapeNoteView: View {
    let art: EscapeClueArt
    let accent: Color
    let onClose: () -> Void

    var body: some View {
        EscapePuzzlePanel(title: "A crumpled note 📜", accent: accent, onClose: onClose) {
            VStack(spacing: 16) {
                switch art {
                case .rowsAndColumns:
                    Text("The door code has two digits…")
                        .font(Theme.rounded(19, .semibold)).foregroundStyle(Theme.ink)
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.96, green: 0.92, blue: 0.82))
                            .frame(height: 180)
                        VStack(spacing: 10) {
                            HStack { Text("1 ➜ Row").font(Theme.rounded(20, .heavy)) }
                            HStack { Text("2 ➜ Column").font(Theme.rounded(20, .heavy)) }
                            Text("❌ where the words cross!")
                                .font(Theme.rounded(18, .bold)).foregroundStyle(Theme.red)
                        }
                        .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.15))
                    }
                case .towerMap:
                    Text("The hero's plan:")
                        .font(Theme.rounded(19, .semibold)).foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Take a core from the Landing", systemImage: "1.circle.fill")
                        Label("Charge it at its matching Charger (solve the game there first!)",
                              systemImage: "2.circle.fill")
                        Label("Carry all 3 charged cores to the Suit", systemImage: "3.circle.fill")
                    }
                    .font(Theme.rounded(18, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.96, green: 0.92, blue: 0.82)))
                case .none:
                    Text("Nothing useful here…")
                        .font(Theme.rounded(18, .semibold)).foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
        }
    }
}
