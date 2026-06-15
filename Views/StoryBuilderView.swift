import SwiftUI

/// Story Builder — the child picks a hero, a place, and a magical object; the app
/// weaves a short illustrated story from those choices and reads back as tappable
/// pages. Encourages narrative thinking (the AI4Kids "AI Storytelling" theme),
/// fully on-device with templated text — no network calls.
struct StoryBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    private struct Choice: Identifiable, Equatable { let id = UUID(); let emoji: String; let name: String }

    private static let heroes = [
        Choice(emoji: "🦊", name: "Fox"), Choice(emoji: "🐉", name: "Dragon"),
        Choice(emoji: "🤖", name: "Robot"), Choice(emoji: "🦄", name: "Unicorn")]
    private static let places = [
        Choice(emoji: "🏰", name: "castle"), Choice(emoji: "🌋", name: "volcano"),
        Choice(emoji: "🌌", name: "galaxy"), Choice(emoji: "🏝️", name: "island")]
    private static let objects = [
        Choice(emoji: "🗝️", name: "golden key"), Choice(emoji: "🔮", name: "magic orb"),
        Choice(emoji: "🎈", name: "flying balloon"), Choice(emoji: "📕", name: "spell book")]

    @State private var hero: Choice?
    @State private var place: Choice?
    @State private var object: Choice?
    @State private var pages: [String] = []
    @State private var pageIndex = 0
    @State private var showCelebration = false

    private var ready: Bool { hero != nil && place != nil && object != nil }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                topBar
                if pages.isEmpty {
                    pickerStage
                } else {
                    readerStage
                }
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)

            if showCelebration {
                CelebrationView(message: "What a story! ⭐️⭐️⭐️")
                    .onTapGesture { reset() }
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

    private var pickerStage: some View {
        ScrollView {
            VStack(spacing: 28) {
                row(title: "Pick your hero", items: Self.heroes, selection: $hero)
                row(title: "Pick a place", items: Self.places, selection: $place)
                row(title: "Pick a magic item", items: Self.objects, selection: $object)
                KidButton(title: "Make my story!", systemImage: "wand.and.stars",
                          color: ready ? Theme.orange : Theme.ink.opacity(0.25)) {
                    if ready { buildStory() }
                }
                .disabled(!ready)
                .padding(.top, 8)
            }
            .padding(.vertical, 8)
        }
    }

    private func row(title: String, items: [Choice], selection: Binding<Choice?>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.rounded(compact ? 20 : 24, .heavy)).foregroundStyle(Theme.ink)
            if compact {
                // Wrap onto multiple rows so four choices fit a phone's width.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)],
                          alignment: .leading, spacing: 12) {
                    ForEach(items) { item in choiceTile(item, selection: selection) }
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(items) { item in choiceTile(item, selection: selection) }
                }
            }
        }
    }

    private func choiceTile(_ item: Choice, selection: Binding<Choice?>) -> some View {
        let isOn = selection.wrappedValue == item
        return Button { selection.wrappedValue = item } label: {
            VStack(spacing: 4) {
                Text(item.emoji).font(.system(size: compact ? 42 : 56))
                Text(item.name)
                    .font(Theme.rounded(compact ? 13 : 15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: compact ? .infinity : 120)
            .frame(height: compact ? 96 : 120)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isOn ? Theme.orange.opacity(0.22) : .white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isOn ? Theme.orange : .clear, lineWidth: 4))
            .softShadow()
        }
        .buttonStyle(.plain)
    }

    private var readerStage: some View {
        VStack(spacing: 24) {
            Text("\(hero!.emoji)\(place!.emoji)\(object!.emoji)")
                .font(.system(size: compact ? 56 : 80))
            Text(pages[pageIndex])
                .font(Theme.rounded(compact ? 22 : 30, .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: compact ? 160 : 220)
                .padding(compact ? 20 : 28)
                .kidCard()
            HStack(spacing: 16) {
                Text("Page \(pageIndex + 1) of \(pages.count)")
                    .font(Theme.rounded(18, .bold)).foregroundStyle(Theme.ink.opacity(0.6))
                Spacer()
                KidButton(title: pageIndex == pages.count - 1 ? "The End!" : "Next",
                          systemImage: "arrow.right", color: Theme.orange) {
                    nextPage()
                }
            }
        }
    }

    private func buildStory() {
        let h = hero!, p = place!, o = object!
        pages = [
            "Once upon a time, a brave \(h.name) \(h.emoji) lived near a \(p.name) \(p.emoji).",
            "One sunny day, the \(h.name) found a \(o.name) \(o.emoji) hidden in the grass!",
            "The \(o.name) began to glow, and the whole \(p.name) lit up with magic ✨.",
            "With a happy heart, the \(h.name) \(h.emoji) shared the magic with every friend. The End! 🎉",
        ]
        pageIndex = 0
    }

    private func nextPage() {
        if pageIndex < pages.count - 1 {
            withAnimation { pageIndex += 1 }
        } else {
            progress.award(3, to: .story)
            withAnimation { showCelebration = true }
        }
    }

    private func reset() {
        showCelebration = false
        pages = []
        hero = nil; place = nil; object = nil
        pageIndex = 0
    }
}
