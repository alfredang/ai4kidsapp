import SwiftUI

/// Story Builder — the child picks a hero, a place, a magic item and a mood; the
/// app weaves a short, twice-branching story (see `StoryEngine`) and reads it back
/// as tappable pages. At each fork the child picks one of two ways forward, so
/// there are four possible endings and every replay reads differently — fully
/// on-device with templated text, no network calls.
struct StoryBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    @State private var hero: StoryChoice?
    @State private var place: StoryChoice?
    @State private var object: StoryChoice?
    @State private var mood: StoryChoice?
    @State private var story: Story?
    /// The branches picked so far — one per resolved fork.
    @State private var chosen: [StoryBranch] = []
    @State private var pageIndex = 0
    @State private var showCelebration = false
    /// Award the finish once per built story, even across "Read again".
    @State private var scored = false

    private var ready: Bool { hero != nil && place != nil && object != nil && mood != nil }

    // MARK: Derived reading state (mirrors the Android BuildMode)

    private var timeline: StoryTimeline? {
        story.map { StoryEngine.buildTimeline(story: $0, chosen: chosen) }
    }
    private var pages: [String] { timeline?.pages ?? [] }
    /// The node whose fork is unanswered: the root until a pick, then the last branch.
    private var pendingNode: (any StoryForkNode)? {
        guard let story else { return nil }
        if chosen.isEmpty { return story }
        return chosen.last
    }
    private var atChoice: Bool {
        guard let timeline, chosen.count < timeline.forks.count else { return false }
        return pageIndex == timeline.forks[chosen.count]
            && pendingNode?.forkChoiceA != nil && pendingNode?.forkChoiceB != nil
    }
    private var pageCount: Int {
        pages.count + StoryEngine.remaining(from: atChoice ? pendingNode : nil)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                topBar
                if story == nil {
                    pickerStage
                } else {
                    readerStage
                }
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)

            if showCelebration {
                celebrationOverlay
            }
        }
    }

    private var topBar: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Story Builder").font(Theme.display(28)).foregroundStyle(Theme.ink)
            Spacer()
            StarBadge(count: progress.stars(for: .story))
        }
    }

    // MARK: Picker

    private var pickerStage: some View {
        ScrollView {
            VStack(spacing: 28) {
                row(title: "Pick your hero", items: StoryEngine.heroes, selection: $hero)
                row(title: "Pick a place", items: StoryEngine.places, selection: $place)
                row(title: "Pick a magic item", items: StoryEngine.objects, selection: $object)
                row(title: "Pick a mood", items: StoryEngine.moods, selection: $mood)
                VStack(spacing: 12) {
                    KidButton(title: "Make my story!", systemImage: "wand.and.stars",
                              color: ready ? Theme.orange : Theme.ink.opacity(0.25)) {
                        if ready { makeStory() }
                    }
                    .disabled(!ready)
                    KidButton(title: "Surprise me!", systemImage: "dice.fill", color: Theme.purple) {
                        surprise()
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 8)
        }
    }

    private func row(title: String, items: [StoryChoice], selection: Binding<StoryChoice?>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.rounded(compact ? 20 : 24, .heavy)).foregroundStyle(Theme.ink)
            // Eight choices side by side would be too cramped to tap, so they wrap
            // onto an adaptive grid on every size class.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 84 : 120), spacing: 12)],
                      alignment: .leading, spacing: 12) {
                ForEach(items) { item in choiceTile(item, selection: selection) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceTile(_ item: StoryChoice, selection: Binding<StoryChoice?>) -> some View {
        let isOn = selection.wrappedValue == item
        return Button { selection.wrappedValue = item } label: {
            VStack(spacing: 4) {
                Text(item.emoji).font(.system(size: compact ? 40 : 48))
                Text(item.name)
                    .font(Theme.rounded(compact ? 13 : 15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 92 : 110)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isOn ? Theme.orange.opacity(0.22) : .white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isOn ? Theme.orange : .clear, lineWidth: 4))
            .softShadow()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Reader

    private var readerStage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("\(hero?.emoji ?? "")\(place?.emoji ?? "")\(object?.emoji ?? "")")
                    .font(.system(size: compact ? 56 : 80))
                Text(pages.indices.contains(pageIndex) ? pages[pageIndex] : "")
                    .font(Theme.rounded(compact ? 22 : 28, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: compact ? 160 : 200)
                    .padding(compact ? 20 : 28)
                    .kidCard()
                    .id(pageIndex) // fresh transition per page
                    .transition(.opacity)

                if atChoice, let a = pendingNode?.forkChoiceA, let b = pendingNode?.forkChoiceB {
                    // A fork: the child picks how the tale continues.
                    VStack(spacing: 12) {
                        choiceButton(a, color: Theme.purple)
                        choiceButton(b, color: Theme.teal)
                    }
                } else {
                    HStack(spacing: 16) {
                        Text("Page \(pageIndex + 1) of \(pageCount)")
                            .font(Theme.rounded(18, .bold)).foregroundStyle(Theme.ink.opacity(0.6))
                        Spacer()
                        KidButton(title: pageIndex == pages.count - 1 ? "The End!" : "Next",
                                  systemImage: "arrow.right", color: Theme.orange) {
                            nextPage()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func choiceButton(_ branch: StoryBranch, color: Color) -> some View {
        Button {
            withAnimation {
                chosen.append(branch) // pages re-derive; next page is the branch's first
                pageIndex += 1
            }
        } label: {
            HStack(spacing: 14) {
                Text(branch.emoji).font(.system(size: compact ? 32 : 40))
                Text(branch.label)
                    .font(Theme.rounded(compact ? 20 : 24, .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, compact ? 14 : 18)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(color))
            .softShadow()
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }

    // MARK: Celebration

    private var celebrationOverlay: some View {
        ZStack {
            CelebrationView(message: "What a story! ⭐️⭐️⭐️")
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    KidButton(title: "Read again", systemImage: "book.fill", color: Theme.teal) {
                        readAgain()
                    }
                    KidButton(title: "New story", systemImage: "arrow.counterclockwise", color: Theme.orange) {
                        reset()
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: Actions

    private func makeStory() {
        guard let h = hero, let p = place, let o = object, let m = mood else { return }
        story = StoryEngine.buildStory(hero: h, place: p, object: o, mood: m)
        chosen = []
        pageIndex = 0
        scored = false
    }

    /// Roll a random pick for every row and build straight away.
    private func surprise() {
        hero = StoryEngine.heroes.randomElement()
        place = StoryEngine.places.randomElement()
        object = StoryEngine.objects.randomElement()
        mood = StoryEngine.moods.randomElement()
        makeStory()
    }

    private func nextPage() {
        if pageIndex < pages.count - 1 {
            withAnimation { pageIndex += 1 }
        } else {
            if !scored {
                scored = true
                progress.award(3, to: .story)
            }
            withAnimation { showCelebration = true }
        }
    }

    /// Same picks, freshly randomized phrasings — and the forks reset, so the
    /// child can try a different path to one of the four endings.
    private func readAgain() {
        showCelebration = false
        makeStory()
    }

    /// Back to the picker for brand-new ingredients.
    private func reset() {
        showCelebration = false
        story = nil
        chosen = []
        hero = nil; place = nil; object = nil; mood = nil
        pageIndex = 0
        scored = false
    }
}
