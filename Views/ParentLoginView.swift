import SwiftUI

/// Grown-up login in front of the AI Workshops. First visit: the parent creates
/// a PIN, pastes their own DeepSeek key (checked live) and gives consent.
/// Later visits: PIN only. Calls `onUnlocked` once a session is open.
struct ParentLoginView: View {
    var onUnlocked: () -> Void = {}

    @Environment(ParentAuth.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if auth.state == .needsSetup {
                        SetupForm(onDone: finish)
                    } else {
                        PINForm(onDone: finish)
                    }
                }
                .padding(24)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("kid_sunny_logo").resizable().scaledToFit().frame(width: 76, height: 76)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(auth.state == .needsSetup ? "Grown-up setup" : "Grown-up login")
                    .font(Theme.display(32)).foregroundStyle(Theme.purple)
                Text(auth.state == .needsSetup
                     ? "Turn on the AI Workshops for your child."
                     : "Enter your Parent PIN to open the AI Workshops.")
                    .font(Theme.rounded(17, .medium)).foregroundStyle(Theme.ink.opacity(0.85))
            }
        }
    }

    private func finish() {
        onUnlocked()
        dismiss()
    }
}

// MARK: - First-time setup

private struct SetupForm: View {
    let onDone: () -> Void
    @Environment(ParentAuth.self) private var auth

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var apiKey = ""
    @State private var consent = false
    @State private var checking = false
    @State private var error: String?

    private var pinOK: Bool { ParentAuth.isValidPIN(pin) && pin == confirmPIN }
    private var canSave: Bool {
        pinOK && consent && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty && !checking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SunnyLabel("How it works", systemImage: "lock.shield")
                    .font(Theme.rounded(19, .heavy)).foregroundStyle(Theme.ink)
                Text("The AI Workshops send what your child types to DeepSeek (api.deepseek.com) to write replies, using your own DeepSeek API key. Nothing else leaves this iPad. No account is created, and your PIN and key stay in this device's Keychain.")
                    .font(Theme.rounded(16, .medium)).foregroundStyle(Theme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20).kidCard()

            step("1  Create a Parent PIN") {
                SunnyField(title: "4–6 digit PIN", text: $pin, secure: true, numeric: true)
                SunnyField(title: "Type it again", text: $confirmPIN, secure: true, numeric: true)
                if !confirmPIN.isEmpty && !pinOK {
                    hint(ParentAuth.isValidPIN(pin) ? "The PINs don't match yet." : "Use 4 to 6 digits.")
                }
            }

            step("2  Add your DeepSeek API key") {
                SunnyField(title: "sk-…", text: $apiKey, secure: true)
                Link(destination: URL(string: "https://platform.deepseek.com/api_keys")!) {
                    Text("Get a key at platform.deepseek.com ↗")
                        .font(Theme.rounded(15, .bold)).foregroundStyle(Theme.teal)
                }
                Text("Usage is billed to your DeepSeek account. You can replace or remove the key any time in Parents' Corner.")
                    .font(Theme.rounded(14, .medium)).foregroundStyle(Theme.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            step("3  Your consent") {
                Toggle(isOn: $consent) {
                    Text("I'm the parent or guardian. I agree that my child's typed messages in the AI Workshops are sent to DeepSeek to generate replies, and I will supervise.")
                        .font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Theme.teal)
            }

            if let error { hint(error) }

            Button(action: save) {
                HStack(spacing: 10) {
                    if checking { ProgressView().tint(.white) }
                    Text(checking ? "Checking key…" : "Check key & save")
                }
                .font(Theme.rounded(19, .heavy)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Capsule().fill(canSave ? Theme.plum : Theme.plum.opacity(0.4)))
                .softShadow()
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSave)
        }
    }

    private func step(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.rounded(18, .heavy)).foregroundStyle(Theme.purple)
            content()
        }
        .padding(20).kidCard()
    }

    private func save() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        checking = true
        error = nil
        Task {
            let result = await DeepSeekClient(apiKey: key).checkKey()
            checking = false
            switch result {
            case .success:
                auth.completeSetup(pin: pin, apiKey: key)
                onDone()
            case .failure(.badKey):
                error = "That key didn't work. Please copy it again from platform.deepseek.com."
            case .failure(.offline):
                error = "Couldn't reach DeepSeek. Check the internet connection and try again."
            case .failure(.noCredit):
                error = "This DeepSeek account has no credit left. Top up, then try again."
            case .failure:
                error = "DeepSeek is busy right now. Please try again in a moment."
            }
        }
    }
}

// MARK: - Returning login

private struct PINForm: View {
    let onDone: () -> Void
    @Environment(ParentAuth.self) private var auth

    @State private var pin = ""
    @State private var message: String?
    @State private var confirmForgot = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parent PIN").font(Theme.rounded(18, .heavy)).foregroundStyle(Theme.purple)
                SunnyField(title: "PIN", text: $pin, secure: true, numeric: true)
                    .focused($focused)
                    .onSubmit(unlock)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let until = auth.cooldownUntil, until > context.date {
                        hint("Too many tries. Please wait \(Int(until.timeIntervalSince(context.date)) + 1) s.")
                    } else if let message {
                        hint(message)
                    }
                }
            }
            .padding(20).kidCard()

            Button(action: unlock) {
                Text("Unlock AI Workshops")
                    .font(Theme.rounded(19, .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(Theme.plum))
                    .softShadow()
            }
            .buttonStyle(PressableStyle())
            .disabled(pin.isEmpty)

            Button("Forgot PIN?") { confirmForgot = true }
                .font(Theme.rounded(16, .bold)).foregroundStyle(Theme.teal)
                .frame(maxWidth: .infinity)
        }
        .onAppear { focused = true }
        .alert("Reset the AI Workshops?", isPresented: $confirmForgot) {
            Button("Reset", role: .destructive) { auth.wipe() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the PIN and the saved DeepSeek key from this device. You'll set up a new PIN and paste your key again.")
        }
    }

    private func unlock() {
        guard !pin.isEmpty else { return }
        switch auth.login(pin: pin) {
        case .success:
            onDone()
        case .wrong(let remaining):
            message = "That PIN isn't right. \(remaining) \(remaining == 1 ? "try" : "tries") left."
        case .coolingDown:
            message = nil
        }
        pin = ""
    }
}

// MARK: - Shared bits

/// Website-style input: soft cream fill with a lavender border.
struct SunnyField: View {
    let title: String
    @Binding var text: String
    var secure = false
    var numeric = false

    var body: some View {
        Group {
            if secure { SecureField(title, text: $text) } else { TextField(title, text: $text) }
        }
        .keyboardType(numeric ? .numberPad : .asciiCapable)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(Theme.rounded(20, .bold))
        .foregroundStyle(Theme.ink)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.inputBorder, lineWidth: 2))
    }
}

private func hint(_ text: String) -> some View {
    Text(text).font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.red)
        .fixedSize(horizontal: false, vertical: true)
}
