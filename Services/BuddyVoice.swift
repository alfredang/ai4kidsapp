import AVFoundation
import Observation

/// Speaks the buddy's replies out loud with the on-device speech synthesizer.
/// Fully offline — Apple's built-in voices, nothing leaves the device.
@MainActor
@Observable
final class BuddyVoice: NSObject, AVSpeechSynthesizerDelegate {
    /// True while the buddy is talking (drives the animated mouth).
    private(set) var speaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
        // Play through the speaker even with the mute switch on — kids expect
        // their buddy to talk.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    /// Speak `text` aloud (emoji are stripped first), replacing any current speech.
    func speak(_ text: String) {
        let clean = Self.stripForSpeech(text)
        guard !clean.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: clean)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.15
        utterance.voice = Self.preferredVoice()
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    /// A friendly English voice, preferring higher-quality installed ones.
    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        return english.first { $0.quality == .premium }
            ?? english.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Remove emoji and other pictographs so the voice reads only words.
    private static func stripForSpeech(_ text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmojiPresentation
              || (scalar.properties.isEmoji && scalar.value > 0x238C))
        })
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate (arrives off the main actor)

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}
