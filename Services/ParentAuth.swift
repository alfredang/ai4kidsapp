import Foundation
import Observation
import CryptoKit
import Security

/// Parent login for the AI Workshops. Everything is on-device: the parent sets
/// a PIN (stored as a salted SHA-256 hash) and pastes their own DeepSeek key,
/// both in the Keychain. A successful login unlocks the workshops for a short
/// session that ends on backgrounding, "Lock now", or after 30 minutes.
@MainActor
@Observable
final class ParentAuth {
    enum State: Equatable { case needsSetup, locked, unlocked }

    private(set) var state: State = .needsSetup
    /// When set, PIN entry is blocked until this moment (after repeated misses).
    private(set) var cooldownUntil: Date?

    static let maxAttempts = 5
    static let cooldown: TimeInterval = 60
    static let sessionLength: TimeInterval = 30 * 60

    private enum Item {
        static let pinHash = "pinHash"
        static let salt = "pinSalt"
        static let apiKey = "deepseekKey"
    }
    private let failsKey = "ai4kids.parent.fails"
    private let cooldownKey = "ai4kids.parent.cooldownUntil"
    private var unlockedAt: Date?

    init() {
        state = isConfigured ? .locked : .needsSetup
        let stamp = UserDefaults.standard.double(forKey: cooldownKey)
        if stamp > Date().timeIntervalSince1970 { cooldownUntil = Date(timeIntervalSince1970: stamp) }
    }

    var isConfigured: Bool {
        Keychain.data(for: Item.pinHash) != nil && Keychain.string(for: Item.apiKey) != nil
    }

    /// True while a valid, unexpired session is open.
    var isUnlocked: Bool { state == .unlocked && !sessionExpired }

    private var sessionExpired: Bool {
        guard let unlockedAt else { return true }
        return Date().timeIntervalSince(unlockedAt) > Self.sessionLength
    }

    /// Locks a session that has outlived `sessionLength` (call on foreground / navigation).
    func expireIfNeeded() {
        if state == .unlocked && sessionExpired { lock() }
    }

    /// The parent's key — only handed out while unlocked.
    var client: DeepSeekClient? {
        guard isUnlocked, let key = Keychain.string(for: Item.apiKey) else { return nil }
        return DeepSeekClient(apiKey: key)
    }

    // MARK: - Setup & login

    static func isValidPIN(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Stores a new PIN + key and opens a session.
    func completeSetup(pin: String, apiKey: String) {
        storePIN(pin)
        Keychain.set(apiKey, for: Item.apiKey)
        resetFails()
        unlockedAt = Date()
        state = .unlocked
    }

    enum LoginResult: Equatable { case success, wrong(remaining: Int), coolingDown }

    func login(pin: String) -> LoginResult {
        if let cooldownUntil, cooldownUntil > Date() { return .coolingDown }
        cooldownUntil = nil
        guard let salt = Keychain.data(for: Item.salt),
              let stored = Keychain.data(for: Item.pinHash),
              Self.hash(pin, salt: salt) == stored
        else {
            let fails = UserDefaults.standard.integer(forKey: failsKey) + 1
            UserDefaults.standard.set(fails, forKey: failsKey)
            if fails >= Self.maxAttempts {
                let until = Date().addingTimeInterval(Self.cooldown)
                cooldownUntil = until
                UserDefaults.standard.set(until.timeIntervalSince1970, forKey: cooldownKey)
                UserDefaults.standard.set(0, forKey: failsKey)
                return .coolingDown
            }
            return .wrong(remaining: Self.maxAttempts - fails)
        }
        resetFails()
        unlockedAt = Date()
        state = .unlocked
        return .success
    }

    func lock() {
        unlockedAt = nil
        if state == .unlocked { state = .locked }
    }

    // MARK: - Parents' Corner management (only offered while unlocked)

    func replaceKey(_ apiKey: String) { Keychain.set(apiKey, for: Item.apiKey) }

    func changePIN(_ pin: String) { storePIN(pin) }

    /// Forgot PIN / turn AI off: wipes the PIN, key and session.
    func wipe() {
        [Item.pinHash, Item.salt, Item.apiKey].forEach(Keychain.delete)
        resetFails()
        unlockedAt = nil
        state = .needsSetup
    }

    // MARK: - Private

    private func storePIN(_ pin: String) {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let salt = Data(bytes)
        Keychain.set(salt, for: Item.salt)
        Keychain.set(Self.hash(pin, salt: salt), for: Item.pinHash)
    }

    private func resetFails() {
        cooldownUntil = nil
        UserDefaults.standard.set(0, forKey: failsKey)
        UserDefaults.standard.removeObject(forKey: cooldownKey)
    }

    private static func hash(_ pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }
}
