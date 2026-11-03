import SwiftUI

/// Home screen — a bright, friendly grid of the seven offline learning
/// activities, the parent-unlocked AI Workshops, a running star total and a
/// small Parents' Corner. Tapping a card opens that activity full-screen.
struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ParentAuth.self) private var auth
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: Activity?
    @State private var selectedWorkshop: AIWorkshop?
    @State private var pendingWorkshop: AIWorkshop?
    @State private var showLogin = false
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

                    workshopsHeader
                        .padding(.top, 16)
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(AIWorkshop.allCases) { workshop in
                            WorkshopCard(workshop: workshop,
                                         stars: progress.stars(forKey: workshop.starKey),
                                         unlocked: auth.isUnlocked) {
                                open(workshop)
                            }
                        }
                    }
                    .padding(.horizontal, compact ? 0 : 8)
                }
                .padding(compact ? 18 : 28)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .fullScreenCover(item: $selectedWorkshop) { workshop in
                AIWorkshopView(workshop: workshop)
            }
        }
        .fullScreenCover(item: $selected) { activity in
            ActivityHost(activity: activity)
        }
        .sheet(isPresented: $showLogin, onDismiss: {
            if auth.isUnlocked, let pendingWorkshop { selectedWorkshop = pendingWorkshop }
            pendingWorkshop = nil
        }) {
            ParentLoginView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Every trip to the background ends the parent session.
            if phase == .background { auth.lock() }
            if phase == .active { auth.expireIfNeeded() }
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
            // Optional launch hook (`-open phonics|story|code|brain|login`) used to deep-link
            // straight into an activity, e.g. for capturing App Store screenshots.
            if let raw = UserDefaults.standard.string(forKey: "open") {
                if let activity = Activity(rawValue: raw) {
                    selected = activity
                } else if raw == "login" {
                    showLogin = true
                }
            }
        }
    }

    /// Opens a workshop, routing through the parent login when locked.
    private func open(_ workshop: AIWorkshop) {
        auth.expireIfNeeded()
        if auth.isUnlocked {
            selectedWorkshop = workshop
        } else {
            pendingWorkshop = workshop
            showLogin = true
        }
    }

    private var workshopsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Workshops")
                    .font(Theme.display(compact ? 28 : 36))
                    .foregroundStyle(Theme.purple)
                Text("Learn AI together · grown-up login needed · powered by DeepSeek")
                    .font(Theme.rounded(compact ? 14 : 16, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                if auth.isUnlocked { auth.lock() } else { pendingWorkshop = nil; showLogin = true }
            } label: {
                HStack(spacing: 6) {
                    SunnyIcon(name: "lock.fill")
                    Text(auth.isUnlocked ? "Lock now" : "Parent login")
                        .font(Theme.rounded(16, .heavy))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Capsule().fill(Theme.card))
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                .softShadow()
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Image("kid_sunny_logo").resizable().scaledToFit().frame(width: compact ? 66 : 90, height: compact ? 66 : 90)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI for Kids")
                    .font(Theme.display(compact ? 38 : 56))
                    .foregroundStyle(Theme.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Little minds. Big adventures. Together.")
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

/// A parent-unlocked AI Workshop tile; shows a lock pill while locked.
struct WorkshopCard: View {
    let workshop: AIWorkshop
    let stars: Int
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(workshop.artwork).resizable().scaledToFit()
                    .frame(width: 104, height: 112)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(workshop.ageBand).font(Theme.rounded(17, .bold)).foregroundStyle(workshop.color)
                        Text(unlocked ? "Unlocked" : "🔒 Grown-up login")
                            .font(Theme.rounded(13, .heavy))
                            .foregroundStyle(unlocked ? Theme.teal : Theme.ink)
                            .padding(.vertical, 4).padding(.horizontal, 10)
                            .background(Capsule().fill(unlocked ? Theme.teal.opacity(0.14) : Theme.yellow.opacity(0.6)))
                    }
                    Text(workshop.title).font(Theme.display(27)).foregroundStyle(workshop.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(workshop.tagline).font(Theme.rounded(18, .medium)).foregroundStyle(Theme.ink.opacity(0.9))
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
        .accessibilityHint(unlocked ? "Opens the workshop" : "Needs a grown-up to log in")
    }
}

/// Parents' Corner — explains the privacy stance, manages the AI Workshops
/// (PIN, DeepSeek key, lock) and offers a progress reset.
struct ParentsCornerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(ParentAuth.self) private var auth
    @State private var confirmReset = false
    @State private var confirmTurnOff = false
    @State private var showLogin = false
    @State private var showReplaceKey = false
    @State private var showChangePIN = false
    @State private var newKey = ""
    @State private var newPIN = ""
    @State private var newPIN2 = ""
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SunnyLabel("The seven play activities work fully offline and collect nothing", systemImage: "wifi.slash")
                    SunnyLabel("No ads, no analytics, no accounts, no servers of ours", systemImage: "hand.raised.fill")
                    SunnyLabel("Designed for ages 4–16", systemImage: "figure.child")
                } header: {
                    Text("About AI4Kids")
                }
                Section {
                    switch auth.state {
                    case .needsSetup:
                        Text("Off. Set a Parent PIN and add your own DeepSeek API key to turn on the four AI Workshops.")
                        Button { showLogin = true } label: {
                            SunnyLabel("Set up AI Workshops", systemImage: "lock.shield")
                        }
                    case .locked:
                        Text("On, and locked. Log in with your Parent PIN to manage the key or PIN.")
                        Button { showLogin = true } label: {
                            SunnyLabel("Parent login", systemImage: "lock.fill")
                        }
                    case .unlocked:
                        Text("On, and unlocked. The session ends when the app is closed, after 30 minutes, or when you lock it.")
                        Button { auth.lock() } label: { SunnyLabel("Lock now", systemImage: "lock.fill") }
                        Button { newKey = ""; showReplaceKey = true } label: {
                            SunnyLabel("Replace DeepSeek API key", systemImage: "lock.shield")
                        }
                        Button { newPIN = ""; newPIN2 = ""; showChangePIN = true } label: {
                            SunnyLabel("Change Parent PIN", systemImage: "lock.shield")
                        }
                        Button(role: .destructive) { confirmTurnOff = true } label: {
                            SunnyLabel("Remove key & turn off AI Workshops", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("AI Workshops")
                } footer: {
                    Text("When on, only the text your child types in a workshop is sent to DeepSeek (api.deepseek.com) to generate a reply, billed to your DeepSeek account. Your PIN and key stay in this device's Keychain. We never see your key or your child's messages.")
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
            .sheet(isPresented: $showLogin) { ParentLoginView() }
            .alert("Replace DeepSeek API key", isPresented: $showReplaceKey) {
                SecureField("sk-…", text: $newKey)
                Button("Check & save") { replaceKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Paste a new key from platform.deepseek.com.")
            }
            .alert("Change Parent PIN", isPresented: $showChangePIN) {
                SecureField("New 4–6 digit PIN", text: $newPIN).keyboardType(.numberPad)
                SecureField("Type it again", text: $newPIN2).keyboardType(.numberPad)
                Button("Save") {
                    if ParentAuth.isValidPIN(newPIN) && newPIN == newPIN2 {
                        auth.changePIN(newPIN)
                        notice = "Parent PIN changed."
                    } else {
                        notice = "PIN not changed: use 4–6 digits and type the same PIN twice."
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Turn off AI Workshops?", isPresented: $confirmTurnOff) {
                Button("Turn off", role: .destructive) { auth.wipe() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the Parent PIN and DeepSeek key from this device.")
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .alert("Reset all progress?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { progress.resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears every star earned. It can't be undone.")
            }
        }
    }

    private func replaceKey() {
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        Task {
            switch await DeepSeekClient(apiKey: key).checkKey() {
            case .success:
                auth.replaceKey(key)
                notice = "New DeepSeek key saved."
            case .failure(.badKey):
                notice = "That key didn't work, so the old key was kept."
            case .failure:
                notice = "Couldn't check the key right now (network or DeepSeek busy). The old key was kept."
            }
        }
    }
}
