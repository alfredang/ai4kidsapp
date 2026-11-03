import Foundation

/// Client-side checks run on every AI Workshop message before it leaves the
/// device: a length cap and a personal-information filter (emails, phone /
/// ID numbers, addresses, passwords). The model's system prompt adds a second,
/// server-side layer of kid-safety rules.
enum KidSafety {
    static let maxLength = 300

    static let privacyNudge =
        "Let's keep personal stuff private! Try asking without your name, phone or address. 🔒"

    private static let patterns: [String] = [
        #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,           // email
        // 7+ digits with at most one space/dash between them (phone, IDs) —
        // so maths like "1000 - 250" still passes.
        #"(?:\d[\s-]?){7,}"#,
        #"\b[STFGM]\d{7}[A-Z]\b"#,                            // Singapore NRIC / FIN
        #"\bmy (home )?address\b"#,
        #"\bi live (at|in) (blk|block)\b"#,
        #"\b(blk|block) \d+"#,
        #"\bmy password\b"#,
        #"\bpostal code\b"#,
    ]

    /// True when the text looks like it contains personal information.
    static func containsPersonalInfo(_ text: String) -> Bool {
        patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// Trims and caps a draft message.
    static func clean(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }
}
