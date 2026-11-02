import SwiftUI

/// Original AI Kids artwork shared with the family website. The name is only
/// a semantic identifier; no SF Symbol is rendered.
struct SunnyIcon: View {
    let name: String
    private var asset: String {
        let n = name.lowercased()
        if n.contains("star") { return "sparkles" }
        if n.contains("xmark") || n.contains("trash") { return "close" }
        if n.contains("check") { return "check" }
        if n.contains("play") { return "play" }
        if n.contains("pause") { return "pause" }
        if n.contains("arrow") || n.contains("chevron") { return n.contains("left") || n.contains("backward") ? "left" : "right" }
        if n.contains("book") || n.contains("story") { return "book" }
        if n.contains("paint") || n.contains("photo") { return "art" }
        if n.contains("person") || n.contains("child") { return "home" }
        if n.contains("lock") || n.contains("hand") || n.contains("wifi") { return "shield" }
        if n.contains("paperplane") { return "send" }
        if n.contains("speaker") || n.contains("mic") || n.contains("bubble") { return "chat" }
        if n.contains("eye") || n.contains("puzzle") { return "maths" }
        if n.contains("smil") { return "science" }
        if n.contains("textformat") { return "wand" }
        if n.contains("door") || n.contains("gamecontroller") { return "bag" }
        return "sun"
    }
    private var rotation: Double { name.contains("arrow.up") || name.contains("chevron.up") ? -90 : name.contains("arrow.down") || name.contains("chevron.down") ? 90 : 0 }
    private var accessibleName: String {
        if name.contains("speaker") { return "Read aloud" }
        return ["close":"Close", "home":"Parents’ Corner", "play":"Play", "pause":"Pause", "send":"Send", "left":"Back", "right":"Next", "chat":"Listen", "check":"Confirm", "sparkles":"Stars", "shield":"Protected", "book":"Story", "art":"Art", "maths":"Puzzle", "sun":"Sunny friend"][asset] ?? "Activity"
    }
    var body: some View {
        Image("kid_" + asset).resizable().scaledToFit()
            .frame(width: 30, height: 30).rotationEffect(.degrees(rotation))
            .accessibilityLabel(accessibleName)
    }
}

struct SunnyLabel: View {
    let title: String
    let systemImage: String
    init(_ title: String, systemImage: String) { self.title=title; self.systemImage=systemImage }
    var body: some View { HStack(spacing: 8) { SunnyIcon(name:systemImage); Text(title) } }
}
