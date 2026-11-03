# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

AI4Kids — a native **universal iPhone + iPad** (iOS/iPadOS 18+) educational activity app for young
learners (ages 4–16), inspired by the AI Kids Academy programme
(<https://ai4kids.tertiarycourses.com.sg/>). SwiftUI, Swift 6 with **complete strict
concurrency** and `@MainActor` isolation. The seven play activities run **fully offline**
with **no data collection**. On top sit four optional, parent-unlocked **AI Workshops**
powered by DeepSeek (see "AI Workshops" below) — the only network traffic in the app.

Seven on-device activities:
- **Phonics Quest** — seven sound worlds of phonics mini-games with on-device phoneme audio.
- **Story Builder** — pick a hero/place/object/mood; the app weaves a twice-branching story.
- **Code Puzzles** — sequence arrows and Scratch-style repeat loops to walk a robot to the goal.
- **Escape Room** — five walk-around puzzle rooms (SwiftUI Canvas port of the Android LibGDX game's solo mode).
- **Art Studio** — compose an on-device picture, then solve it as a tap-to-place jigsaw.
- **Talking Buddy** — rule-based offline chat pal with speech synthesis.
- **Brain Arcade** — eight quick solo card games (SwiftUI port of the Android arcade's solo subset).

Four AI Workshops (mirroring the website's December workshops): **Storybook Studio**,
**Mini Maker Studio**, **Maths Detectives**, **Science Explorers** — a chat with "Sunny"
via the DeepSeek chat-completions API (`deepseek-flash`, thinking disabled).

Progress is a simple star tally persisted locally in `UserDefaults` via
[Services/ProgressStore.swift](Services/ProgressStore.swift) — no SwiftData, no CloudKit.

## Build & run

The `.xcodeproj` is **generated** from `project.yml` via [XcodeGen](https://github.com/yonsm/XcodeGen)
and is **not** the source of truth — never hand-edit it. After changing `project.yml`,
sources, settings, or Info.plist wiring, regenerate:

```bash
xcodegen generate            # brew install xcodegen (once)
```

Command-line build (signing off, generic device):

```bash
xcodebuild -project AI4KidsApp.xcodeproj -scheme AI4KidsApp \
  -destination 'generic/platform=iOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

Build + run on a booted iPad simulator:

```bash
xcodebuild -project AI4KidsApp.xcodeproj -scheme AI4KidsApp -configuration Debug \
  -destination 'id=<SIMULATOR_UDID>' -derivedDataPath /tmp/dd build
xcrun simctl install <UDID> /tmp/dd/Build/Products/Debug-iphonesimulator/AI4KidsApp.app
xcrun simctl launch <UDID> com.tertiaryinfotech.ai4kids
```

There is **no test target** (`testTargets: []`).

## Architecture

```
SwiftUI Views (one per activity) ─> ProgressStore (@Observable, UserDefaults)
RootView (home grid) ─> fullScreenCover ─> activity views
```

- `App/` — entry point, `RootView` (home grid + Parents' Corner behind `Views/ParentalGate.swift`), `Theme` (kid palette + helpers).
- `Models/Activity.swift` — the seven offline activities and their card metadata.
- `Models/AIWorkshop.swift` — the four AI Workshops: card metadata, starter chips, kid-safety system prompts.
- `Models/KidSafety.swift` — client-side length cap + personal-info filter run before any message is sent.
- `Services/ProgressStore.swift` — `@Observable` star tally (UserDefaults).
- `Services/ParentAuth.swift` — `@Observable` parent session: PIN (salted SHA-256) + parent's DeepSeek key in the Keychain (`Services/Keychain.swift`); locks on background / 30 min / "Lock now".
- `Services/DeepSeekClient.swift` — the **only** networking code in the app.
- `Components/SharedUI.swift` — `KidButton`, `StarBadge`, `CelebrationView`, `CloseButton`.
- `Views/` — one self-contained SwiftUI view per activity.

## Conventions

- Everything is `@MainActor`; state is `@Observable` (Observation framework, not Combine).
- Keep types `Sendable` where they cross concurrency boundaries — strict concurrency is `complete`.
- No network calls outside `DeepSeekClient`, and only while a parent session is unlocked.
  No analytics/ads SDKs, no servers of our own, **no developer API key in the binary** —
  the parent supplies their own DeepSeek key. Any new off-device data flow must update
  `Resources/PrivacyInfo.xcprivacy`, the App Privacy label and the Parents' Corner copy.

## AI Workshops

- Locked by default. Tapping a workshop opens `ParentLoginView`: first run = create a
  4–6 digit PIN + paste a DeepSeek key (validated via `GET /models`) + consent; later = PIN.
  5 wrong PINs → 60 s cooldown. "Forgot PIN" wipes PIN + key.
- Every message passes `KidSafety` first; history (last 10 turns) lives in memory only.
- The app left Apple's **Kids Category** in v1.6 because of this third-party AI data flow
  (guideline 5.1.4). App Privacy label: "Other User Content", not linked, not tracking,
  App Functionality. App Review needs a demo key + PIN in the review notes.
- Shared spec with the Android app: same four workshops, prompts and parent-login rules.

## App Store submission

Driven by the bundled `app-store-submission` skill (`.claude/skills/`) + the App Store
Connect API key in `.env` (gitignored). See the skill's SKILL.md for the full flow.
