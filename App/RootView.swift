import SwiftUI

/// Home screen — a bright, friendly grid of the seven learning activities plus a
/// running star total and a small Parents' Corner. Tapping a card opens that
/// activity full-screen.
struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selected: Activity?
    @State private var showParents = false
    @State private var gatePassed = false

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
                VStack(spacing: 20) {
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
            if gatePassed {
                ParentsCornerView()
            } else {
                // Parental gate before the grown-ups area (it holds the progress
                // reset) — same math-challenge gate as the Android app. The gate
                // re-arms every time the sheet is opened.
                ParentalGate(
                    title: "Grown-ups only",
                    message: "The Parents' Corner explains AI4Kids' privacy approach and can " +
                        "reset all progress. A parent or guardian: please confirm by solving " +
                        "the problem below.",
                    confirmLabel: "I'm a grown-up — continue",
                    onConsent: { gatePassed = true }
                )
            }
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
            Image("kid_sunny_logo").resizable().scaledToFit().frame(width: compact ? 66 : 90, height: compact ? 66 : 90)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Kids")
                    .font(Theme.display(compact ? 38 : 56))
                    .foregroundStyle(Theme.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Little minds. Big ideas.")
                    .font(Theme.rounded(compact ? 16 : 22, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            StarBadge(count: progress.totalStars)
            Button { gatePassed = false; showParents = true } label: {
                SunnyIcon(name: "person.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(Circle().fill(.white))
                    .softShadow()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Parents’ Corner")
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
        case .escape:  EscapeRoomView()
        case .art:     ArtStudioView()
        case .buddy:   TalkingBuddyView()
        case .brain:   BrainArcadeView()
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
            HStack(spacing: 18) {
                Image(activity.artwork).resizable().scaledToFit()
                    .frame(width: 104, height: 112)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(activity.ageBand).font(Theme.rounded(17, .bold)).foregroundStyle(activity.color)
                    Text(activity.title).font(Theme.display(27)).foregroundStyle(activity.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(activity.subtitle).font(Theme.rounded(18, .medium)).foregroundStyle(Theme.ink.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        SunnyIcon(name: "star.fill")
                        Text("\(stars) stars").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 175, alignment: .leading)
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
                    SunnyLabel("Plays fully offline — no internet needed", systemImage: "wifi.slash")
                    SunnyLabel("No login, no ads, no data collected", systemImage: "hand.raised.fill")
                    SunnyLabel("Designed for ages 4–16", systemImage: "figure.child")
                }
                Section("Progress") {
                    HStack {
                        Text("Total stars earned")
                        Spacer()
                        Text("\(progress.totalStars)").bold()
                    }
                    Button(role: .destructive) { confirmReset = true } label: {
                        SunnyLabel("Reset all progress", systemImage: "arrow.counterclockwise")
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
