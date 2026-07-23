import SwiftUI

/// Talking Buddy — chat with a friendly robot pal who talks back out loud.
/// Fully offline: replies come from the curated `BuddyBrain` (no AI service,
/// no network) and are spoken with the on-device synthesizer via `BuddyVoice`.
struct TalkingBuddyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var progress
    @Environment(\.horizontalSizeClass) private var hSize
    private var compact: Bool { hSize == .compact }

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let fromBuddy: Bool
    }

    @State private var brain = BuddyBrain()
    @State private var voice = BuddyVoice()
    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var starsEarned = 0
    @FocusState private var typing: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, compact ? 16 : 28)
                    .padding(.top, compact ? 12 : 20)
                BuddyFace(speaking: voice.speaking)
                    .frame(height: compact ? 130 : 180)
                    .padding(.top, 6)
                chat
                chips
                inputBar
            }
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            let hello = BuddyBrain.greeting
            messages.append(Message(text: hello, fromBuddy: true))
            voice.speak(hello)
        }
        .onDisappear { voice.stop() }
    }

    private var topBar: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Talking Buddy")
                .font(Theme.display(compact ? 24 : 30))
                .foregroundStyle(Theme.ink)
            Spacer()
            StarBadge(count: progress.stars(for: .buddy))
        }
    }

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { message in
                        bubble(for: message)
                    }
                }
                .padding(.horizontal, compact ? 16 : 28)
                .padding(.vertical, 14)
            }
            .onChange(of: messages) {
                if let last = messages.last {
                    withAnimation(.spring(duration: 0.35)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func bubble(for message: Message) -> some View {
        HStack {
            if !message.fromBuddy { Spacer(minLength: 40) }
            HStack(alignment: .top, spacing: 8) {
                if message.fromBuddy { Text("🤖").font(.system(size: 26)) }
                Text(message.text)
                    .font(Theme.rounded(compact ? 18 : 20, .semibold))
                    .foregroundStyle(message.fromBuddy ? Theme.ink : .white)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(message.fromBuddy ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.blue)))
            .softShadow()
            if message.fromBuddy { Spacer(minLength: 40) }
        }
        .id(message.id)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BuddyBrain.quickChips, id: \.self) { chip in
                    Button {
                        send(chip)
                    } label: {
                        Text(chip)
                            .font(Theme.rounded(17, .bold))
                            .foregroundStyle(Theme.blue)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Capsule().fill(.white))
                            .softShadow()
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, compact ? 16 : 28)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message…", text: $draft)
                .font(Theme.rounded(19, .semibold))
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(Capsule().fill(.white))
                .softShadow()
            Button {
                send(draft)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Circle().fill(Theme.blue))
                    .softShadow()
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, compact ? 16 : 28)
        .padding(.bottom, compact ? 12 : 20)
        .padding(.top, 4)
    }

    private func send(_ raw: String) {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !text.isEmpty else { return }
        draft = ""
        typing = false
        messages.append(Message(text: text, fromBuddy: false))

        let reply = brain.reply(to: text)
        // A tiny pause makes the buddy feel like it's "thinking".
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            messages.append(Message(text: reply, fromBuddy: true))
            voice.speak(reply)
            if starsEarned < 3 {
                starsEarned += 1
                progress.award(1, to: .buddy)
            }
        }
    }
}

/// The buddy's animated robot face: blinking eyes and a mouth that flaps
/// while the voice is speaking.
struct BuddyFace: View {
    let speaking: Bool
    @State private var blink = false
    @State private var mouthOpen = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Theme.blue.gradient)
                .frame(width: 170, height: 150)
                .softShadow()
            // Antenna
            Circle().fill(Theme.yellow).frame(width: 18, height: 18).offset(y: -88)
            Capsule().fill(Theme.blue).frame(width: 6, height: 22).offset(y: -74)

            VStack(spacing: 20) {
                HStack(spacing: 36) {
                    eye
                    eye
                }
                Capsule()
                    .fill(.white)
                    .frame(width: 64, height: mouthOpen ? 30 : 8)
                    .animation(.easeInOut(duration: 0.16), value: mouthOpen)
            }
            .offset(y: 6)
        }
        .task {
            // Blink every few seconds, forever.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                blink = true
                try? await Task.sleep(for: .milliseconds(140))
                blink = false
            }
        }
        .task(id: speaking) {
            // Flap the mouth while speaking.
            guard speaking else {
                mouthOpen = false
                return
            }
            while !Task.isCancelled && speaking {
                mouthOpen.toggle()
                try? await Task.sleep(for: .milliseconds(170))
            }
            mouthOpen = false
        }
    }

    private var eye: some View {
        Capsule()
            .fill(.white)
            .frame(width: 26, height: blink ? 4 : 30)
            .animation(.easeInOut(duration: 0.1), value: blink)
    }
}
