# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

AI4Kids — a native **iPad-only** (iPadOS 18+) educational activity app for young
learners (ages 4–16), inspired by the AI Kids Academy programme
(<https://ai4kids.tertiarycourses.com.sg/>). SwiftUI, Swift 6 with **complete strict
concurrency** and `@MainActor` isolation. Everything runs **fully offline** — no login,
no accounts, no network access, and **no data collection** (kid-safe / COPPA-friendly).

Four on-device activities:
- **Phonics Playground** — tap the picture that starts with the shown letter.
- **Story Builder** — pick a hero/place/object; the app weaves an illustrated story.
- **Code Puzzles** — sequence direction steps to walk a robot to the goal (algorithmic thinking).
- **Brain Games** — emoji pair-matching.

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

- `App/` — entry point, `RootView` (home grid + Parents' Corner), `Theme` (kid palette + helpers).
- `Models/Activity.swift` — the four activities and their card metadata.
- `Services/ProgressStore.swift` — the single `@Observable` injected into the environment; **only** place that persists.
- `Components/SharedUI.swift` — `KidButton`, `StarBadge`, `CelebrationView`, `CloseButton`.
- `Views/` — one self-contained SwiftUI view per activity.

## Conventions

- Everything is `@MainActor`; state is `@Observable` (Observation framework, not Combine).
- Keep types `Sendable` where they cross concurrency boundaries — strict concurrency is `complete`.
- No network calls, ever. No analytics SDKs. This is a core product constraint for a kids' app.

## App Store submission

Driven by the bundled `app-store-submission` skill (`.Codex/skills/`) + the App Store
Connect API key in `.env` (gitignored). See the skill's SKILL.md for the full flow.
