import SwiftUI

/// App entry point. AI4Kids — a fully on-device, no-login iPad activity app for
/// young learners. A single shared `ProgressStore` is injected into the
/// environment for every activity to read and award stars.
@main
struct AI4KidsApp: App {
    @State private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(progress)
        }
    }
}
