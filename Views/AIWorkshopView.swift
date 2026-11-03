import SwiftUI

/// One AI Workshop: a chat with "Sunny", powered by DeepSeek using the
/// parent's key. Only open while the parent session is unlocked — if the
/// session locks (backgrounding, timeout, bad key) the screen closes itself.
/// Messages are screened by `KidSafety` first and kept in memory only.
struct AIWorkshopView: View {
    let workshop: AIWorkshop

    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(ParentAuth.self) private var auth
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let fromSunny: Bool
        /// Local-only notes (privacy nudges, errors) are never sent as history.
        var local = false
    }

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var thinking = false
    @State private var starsEarned = 0
    @State private var voice = BuddyVoice()
    @FocusState private var typing: Bool

    /// Conversation turns kept as context for the model.
    private let historyLimit = 10

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, compact ? 16 : 28)
                    .padding(.top, compact ? 12 : 20)
                chat
                chips
                inputBar
                Text("AI can make mistakes — check answers with a grown-up. Powered by DeepSeek.")
                    .font(Theme.rounded(13, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, compact ? 8 : 14)
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            if messages.isEmpty {
                messages.append(Message(text: workshop.greeting, fromSunny: true, local: true))
            }
        }
        .onChange(of: auth.state) { _, state in
            if state != .unlocked { dismiss() }
        }
        .onDisappear { voice.stop() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CloseButton { dismiss() }
            Image(workshop.artwork).resizable().scaledToFit().frame(width: 52, height: 52)
                .accessibilityHidden(true)
            Text(workshop.title)
                .font(Theme.display(compact ? 22 : 30))
                .foregroundStyle(workshop.color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            StarBadge(count: progress.stars(forKey: workshop.starKey))
        }
    }

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { bubble(for: $0) }
                    if thinking {
                        HStack(spacing: 10) {
                            ProgressView().tint(workshop.color)
                            Text("Sunny is thinking…")
                                .font(Theme.rounded(17, .semibold)).foregroundStyle(Theme.ink.opacity(0.8))
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(.horizontal, compact ? 16 : 28)
                .padding(.vertical, 14)
            }
            .onChange(of: messages) {
                if let last = messages.last {
                    withAnimation(.spring(duration: 0.35)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: thinking) {
                if thinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
        }
    }

    private func bubble(for message: Message) -> some View {
        HStack(alignment: .bottom) {
            if !message.fromSunny { Spacer(minLength: 48) }
            HStack(alignment: .top, spacing: 8) {
                if message.fromSunny {
                    Image("kid_sunny_logo").resizable().scaledToFit().frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                }
                Text(message.text)
                    .font(Theme.rounded(compact ? 18 : 20, .semibold))
                    .foregroundStyle(message.fromSunny ? Theme.ink : .white)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(message.fromSunny ? AnyShapeStyle(Theme.card) : AnyShapeStyle(workshop.color)))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(message.fromSunny ? Theme.ink.opacity(0.2) : .clear, lineWidth: 1.5))
            .softShadow()
            if message.fromSunny {
                Button { voice.speak(message.text) } label: {
                    SunnyIcon(name: "speaker.wave.2.fill")
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                Spacer(minLength: 24)
            }
        }
        .id(message.id)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(workshop.starters, id: \.self) { chip in
                    Button { send(chip) } label: {
                        Text(chip)
                            .font(Theme.rounded(17, .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Capsule().fill(Theme.card))
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                            .softShadow()
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(thinking)
                }
            }
            .padding(.horizontal, compact ? 16 : 28)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type your idea…", text: $draft, axis: .vertical)
                .lineLimit(1...3)
                .font(Theme.rounded(19, .semibold))
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.inputBorder, lineWidth: 2))
                .onChange(of: draft) {
                    if draft.count > KidSafety.maxLength { draft = String(draft.prefix(KidSafety.maxLength)) }
                }
            Button { send(draft) } label: {
                SunnyIcon(name: "paperplane.fill")
                    .padding(16)
                    .background(Circle().fill(workshop.color))
                    .softShadow()
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .disabled(thinking || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, compact ? 16 : 28)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private func send(_ raw: String) {
        let text = KidSafety.clean(raw)
        guard !text.isEmpty, !thinking else { return }
        draft = ""
        typing = false
        messages.append(Message(text: text, fromSunny: false))

        if KidSafety.containsPersonalInfo(text) {
            messages[messages.count - 1].local = true
            messages.append(Message(text: KidSafety.privacyNudge, fromSunny: true, local: true))
            return
        }
        guard let client = auth.client else {
            auth.lock()
            return
        }

        let history = messages.filter { !$0.local }.suffix(historyLimit).map {
            DeepSeekClient.Message(role: $0.fromSunny ? "assistant" : "user", content: $0.text)
        }
        let request = [DeepSeekClient.Message(role: "system", content: workshop.systemPrompt)] + history

        thinking = true
        Task {
            let result = await client.chat(request)
            thinking = false
            switch result {
            case .success(let reply):
                messages.append(Message(text: reply, fromSunny: true))
                if starsEarned < 3 {
                    starsEarned += 1
                    progress.award(1, key: workshop.starKey)
                }
            case .failure(let failure):
                messages.append(Message(text: Self.friendly(failure), fromSunny: true, local: true))
            }
        }
    }

    private static func friendly(_ failure: DeepSeekClient.Failure) -> String {
        switch failure {
        case .badKey:   return "Hmm, my magic key stopped working. 🔑 Please ask a grown-up to check it in Parents' Corner."
        case .noCredit: return "I've run out of thinking power for now. ⚡️ Ask a grown-up to top up the DeepSeek account."
        case .offline:  return "I can't reach the internet. 📶 Ask a grown-up to check the Wi-Fi, then try again!"
        case .busy, .unexpected:
            return "The AI is taking a little nap. 😴 Please try again in a moment."
        }
    }
}
