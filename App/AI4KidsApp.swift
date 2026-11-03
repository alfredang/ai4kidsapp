import SwiftUI

/// App entry point. AI4Kids — an on-device iPad activity app for young learners,
/// plus parent-unlocked AI Workshops. A shared `ProgressStore` (stars) and
/// `ParentAuth` (parent PIN + DeepSeek key session) are injected into the
/// environment.
@main
struct AI4KidsApp: App {
    @State private var progress = ProgressStore()
    @State private var auth = ParentAuth()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(progress)
                .environment(auth)
        }
    }
}
