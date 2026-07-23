import AVFoundation
import Observation

/// All sound for Phonics Quest: whole *words* through the system speech
/// synthesizer, isolated *sounds* through pre-recorded phoneme clips bundled in
/// the app (Resources/Phonemes/*.mp3, bundled flat).
///
/// Audio is keyed by *phoneme*, never by letter — a letter has many sounds
/// (c=/k/ or /s/, g=/g/ or /dʒ/, every vowel), so only a phoneme slug is
/// unambiguous. Playback is fully **on-device**: nothing leaves the device,
/// keeping the offline / no-collection posture of the phonics activity. Speech
/// can't stand in for the clips — it reads text *as words*, so "ah" ≠ /æ/.
///
/// One class owns both channels so they can be coordinated — `play(_:)`
/// silences an in-flight spoken word before sounding a clip, otherwise the two
/// overlap and the clean sound comes out muddied.
@MainActor
@Observable
final class PhonicsAudio {
    /// Phoneme clips play a touch under real-time so a young child can catch
    /// each sound. 1 = the raw recording; lower = slower. `AVAudioPlayer`
    /// time-stretches without dropping pitch, so it slows without going muddy.
    private static let phonemeRate: Float = 0.67

    /// Slightly slow, friendly speaking rate for whole words.
    private static let speechRate: Float = 0.42

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var player: AVAudioPlayer?

    init() {
        // .playback so the quest is audible even with the silent switch on —
        // sound *is* the lesson here.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Speak a whole word (or a short praise sentence) with a friendly,
    /// slightly slow voice. Cuts any clip or previous speech first.
    func speak(_ text: String) {
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Self.speechRate
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        synthesizer.speak(utterance)
    }

    /// Play the phoneme clip for `slug`, suspending until the sound actually
    /// finishes — callers time their pauses from the *silence* rather than from
    /// the call, so a sound-out stays smooth at any playback rate.
    ///
    /// An empty `slug` (a silent letter) plays nothing and returns at once —
    /// that silence is the lesson in Whisper Woods. An unknown slug degrades
    /// silently, never crashes.
    ///
    /// No `AVAudioPlayerDelegate` is involved: completion is awaited with an
    /// async sleep sized to the clip's stretched duration, so everything stays
    /// on the main actor with no cross-isolation delegate hops.
    func play(_ slug: String) async {
        guard !slug.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: slug, withExtension: "mp3") else { return }

        // Silence any in-flight spoken word and any previous clip first.
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()

        guard let clip = try? AVAudioPlayer(contentsOf: url) else { return }
        clip.enableRate = true
        clip.rate = Self.phonemeRate
        player = clip
        clip.play()

        let stretched = clip.duration / Double(Self.phonemeRate)
        // Task.sleep throws when the caller is cancelled (child advanced or
        // replayed mid-sound-out) — cut the clip so it can't bleed on.
        do {
            try await Task.sleep(for: .seconds(stretched + 0.03))
        } catch {
            if player === clip { clip.stop() }
        }
        // Only clean up if we still own the player; a newer sound may have
        // superseded this one and now owns the field.
        if player === clip { player = nil }
    }

    /// Sound out a sequence of phonemes with a small beat of real silence held
    /// AFTER each clip has fully played (used by BUILD and BLEND rounds).
    /// Silent-letter slugs ("") are skipped. Respects task cancellation.
    func playSounds(_ slugs: [String], gap: Duration = .milliseconds(50)) async {
        for slug in slugs where !slug.isEmpty {
            guard !Task.isCancelled else { return }
            await play(slug)
            try? await Task.sleep(for: gap)
        }
    }

    /// Cut everything now: the current clip and any spoken word. Used when the
    /// child leaves a round mid-sound-out, so nothing bleeds into the next.
    func stop() {
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
    }
}
