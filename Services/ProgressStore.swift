import SwiftUI
import Observation

/// App-wide progress: stars earned per activity, persisted locally to
/// `UserDefaults` (Codable JSON). No accounts, no network, no personal data —
/// just a fun running tally so kids see their stars grow.
@MainActor
@Observable
final class ProgressStore {
    /// Stars earned per activity id.
    private(set) var stars: [String: Int]

    private let defaultsKey = "ai4kids.progress.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stars = decoded
        } else {
            stars = [:]
        }
    }

    /// Total stars across every activity.
    var totalStars: Int { stars.values.reduce(0, +) }

    /// Stars earned in a single activity.
    func stars(for activity: Activity) -> Int { stars[activity.id, default: 0] }

    /// Award `count` stars for an activity and persist immediately.
    func award(_ count: Int, to activity: Activity) {
        guard count > 0 else { return }
        stars[activity.id, default: 0] += count
        persist()
    }

    /// Reset all progress (used by the parents' corner).
    func resetAll() {
        stars = [:]
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(stars) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
