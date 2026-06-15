import SwiftUI

/// Home screen — a bright, friendly grid of the four learning activities plus a
/// running star total and a small Parents' Corner. Tapping a card opens that
/// activity full-screen.
struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selected: Activity?
    @State private var showParents = false

    /// iPhone (and Split View) report a compact width; full-screen iPad is regular.
    private var compact: Bool { hSize == .compact }

    private var columns: [GridItem] {
        compact
            ? [GridItem(.flexible(), spacing: 16)]
            : [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Activity.allCases) { activity in
                            ActivityCard(activity: activity,
                                         stars: progress.stars(for: activity)) {
                                selected = activity
                            }
                        }
                    }
                    .padding(.horizontal, compact ? 0 : 8)
                }
                .padding(compact ? 18 : 28)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(item: $selected) { activity in
            ActivityHost(activity: activity)
        }
        .sheet(isPresented: $showParents) {
            ParentsCornerView()
        }
        .onAppear {
            // Optional launch hook (`-open phonics|story|code|brain`) used to deep-link
            // straight into an activity, e.g. for capturing App Store screenshots.
            if let raw = UserDefaults.standard.string(forKey: "open"),
               let activity = Activity(rawValue: raw) {
                selected = activity
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI4Kids")
                    .font(Theme.display(compact ? 38 : 56))
                    .foregroundStyle(Theme.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Play. Learn. Create.")
                    .font(Theme.rounded(compact ? 16 : 22, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            StarBadge(count: progress.totalStars)
            Button { showParents = true } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(Circle().fill(.white))
                    .softShadow()
            }
            .buttonStyle(.plain)
        }
    }
}

/// Routes the chosen `Activity` to its full-screen view.
private struct ActivityHost: View {
    let activity: Activity
    var body: some View {
        switch activity {
        case .phonics: PhonicsView()
        case .story:   StoryBuilderView()
        case .code:    CodePuzzlesView()
        case .brain:   BrainGamesView()
        }
    }
}

/// A single tappable activity tile.
struct ActivityCard: View {
    let activity: Activity
    let stars: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: activity.symbol)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(activity.color))
                    Spacer()
                    Text(activity.ageBand)
                        .font(Theme.rounded(15, .bold))
                        .foregroundStyle(activity.color)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(activity.color.opacity(0.15)))
                }
                Text(activity.title)
                    .font(Theme.rounded(28, .heavy))
                    .foregroundStyle(Theme.ink)
                Text(activity.subtitle)
                    .font(Theme.rounded(18, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
                    Text("\(stars) stars")
                        .font(Theme.rounded(16, .bold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .kidCard()
        }
        .buttonStyle(PressableStyle())
    }
}

/// Parents' Corner — explains the no-data-collection stance and offers a reset.
struct ParentsCornerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("About AI4Kids") {
                    Label("Plays fully offline — no internet needed", systemImage: "wifi.slash")
                    Label("No login, no ads, no data collected", systemImage: "hand.raised.fill")
                    Label("Designed for ages 4–16", systemImage: "figure.child")
                }
                Section("Progress") {
                    HStack {
                        Text("Total stars earned")
                        Spacer()
                        Text("\(progress.totalStars)").bold()
                    }
                    Button(role: .destructive) { confirmReset = true } label: {
                        Label("Reset all progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Parents' Corner")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset all progress?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { progress.resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears every star earned. It can't be undone.")
            }
        }
    }
}
