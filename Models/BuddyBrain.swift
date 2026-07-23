import Foundation

/// The Talking Buddy's fully offline "brain": a friendly rule-based reply
/// engine for young kids (ages 5–10). No AI service, no network — every reply
/// comes from these curated, wholesome pools. Keyword groups are checked in
/// priority order; anything unmatched gets a cheerful conversation-starter.
struct BuddyBrain: Sendable {
    /// Set while a riddle is waiting for its answer, so the next turn can reveal it.
    private(set) var pendingRiddleAnswer: String?

    static let greeting = "Hi friend! I'm Buddy! 🤖 Tap a bubble below, or tell me anything!"

    /// Quick-tap conversation starters shown above the keyboard.
    static let quickChips: [String] = [
        "Tell me a joke 😂",
        "Animal fact 🐾",
        "Ask me a riddle 🧩",
        "Space fact 🚀",
        "Sing a rhyme 🎵",
        "Dinosaur fact 🦖",
    ]

    // MARK: - Reply pools

    private static let jokes = [
        "Why did the banana go to the doctor? Because it wasn't peeling well! 🍌😂",
        "What do you call a dinosaur that is sleeping? A dino-SNORE! 🦖💤",
        "Why did the cookie go to the doctor? Because it was feeling crummy! 🍪",
        "What do you call a fish with no eyes? A fsh! 🐟😄",
        "Why can't Elsa have a balloon? Because she will let it go! 🎈",
        "What is a cat's favorite color? Purr-ple! 🐱💜",
        "Why did the teddy bear say no to dessert? Because he was stuffed! 🧸",
        "What do you call a boomerang that won't come back? A stick! 🪃",
        "Why do bees have sticky hair? Because they use honey combs! 🐝",
        "What kind of music do planets like? Nep-TUNES! 🪐🎵",
    ]

    private static let riddles: [(question: String, answer: String)] = [
        ("I have keys but I can't open doors. What am I? Say 'answer' when you give up! 🧩",
         "A piano! 🎹 Its keys make music, not doors open!"),
        ("What has to be broken before you can use it? Say 'answer' if you're stuck! 🧩",
         "An egg! 🥚 Crack! Now let's make a yummy omelette!"),
        ("I'm tall when I'm young and short when I'm old. What am I? 🧩",
         "A candle! 🕯️ It melts down as it glows!"),
        ("What has hands but cannot clap? 🧩",
         "A clock! 🕐 Tick tock, its hands just point!"),
        ("What gets wetter the more it dries? 🧩",
         "A towel! 🛁 It dries you and gets wet itself!"),
        ("I have a face and two hands but no arms or legs. What am I? 🧩",
         "A clock! ⏰ Did I trick you with that one?"),
    ]

    private static let animalFacts = [
        "Octopuses have THREE hearts! 🐙 Imagine three little heartbeats!",
        "A group of flamingos is called a flamboyance! 🦩 Fancy, right?",
        "Elephants can't jump — but they can swim really well! 🐘💦",
        "Sea otters hold hands while they sleep so they don't float away! 🦦💕",
        "A snail can sleep for three whole years! 🐌💤",
        "Penguins propose with a pebble! 🐧 They give their favorite stone to a friend!",
        "Dogs can smell about 10,000 times better than people! 🐶👃",
        "Butterflies taste with their FEET! 🦋 Imagine tasting ice cream with your toes!",
        "Cows have best friends and get sad when they're apart! 🐮💛",
        "A cheetah can run as fast as a car on the highway! 🐆💨",
    ]

    private static let spaceFacts = [
        "The Sun is so big that a MILLION Earths could fit inside it! ☀️🌍",
        "One day on Venus is longer than its whole year! 🪐 How silly is that?",
        "Astronauts grow a little taller in space! 🧑‍🚀 Space stretches you!",
        "The footprints on the Moon will stay there for millions of years! 👣🌙",
        "Saturn is so light it could float in a giant bathtub! 🛁🪐",
        "Shooting stars are really tiny space rocks burning up! 💫",
        "Jupiter has a storm bigger than the whole Earth! 🌪️ It's called the Great Red Spot!",
    ]

    private static let dinoFacts = [
        "The T. rex had teeth as long as bananas! 🦖🍌",
        "Some dinosaurs were as small as chickens! 🐔 Tiny dinos!",
        "Birds are actually dinosaurs' great-great-great grandkids! 🐦🦕",
        "The Brachiosaurus was as tall as a four-story building! 🦕🏢",
        "Stegosaurus had a brain the size of a walnut! 🥜 But big spiky armor!",
        "Triceratops had three horns and a giant frill, like a super shield! 🛡️🦖",
    ]

    private static let seaFacts = [
        "The blue whale's heart is as big as a small car! 🐋🚗",
        "Starfish don't have brains — but they can grow back their arms! ⭐🌊",
        "Seahorse daddies carry the babies! 🌊🐴 Super dads!",
        "Dolphins call each other by name with special whistles! 🐬",
        "Jellyfish have been around longer than dinosaurs! 🪼",
    ]

    private static let rhymes = [
        "Twinkle, twinkle, little star, how I wonder what you are! ⭐ Up above the world so high, like a diamond in the sky! 🎵",
        "The itsy bitsy spider climbed up the water spout! 🕷️ Down came the rain and washed the spider out! 🌧️🎵",
        "Row, row, row your boat, gently down the stream! 🚣 Merrily, merrily, merrily, merrily, life is but a dream! 🎵",
        "Old MacDonald had a farm, E-I-E-I-O! 🐮 And on that farm he had a cow, E-I-E-I-O! 🎵",
        "Baa, baa, black sheep, have you any wool? 🐑 Yes sir, yes sir, three bags full! 🎵",
    ]

    private static let feelings = [
        "I feel super happy today because I'm talking to YOU! 😄💛",
        "I'm feeling great! Robots feel extra good when they make a new friend! 🤖💕",
        "I'm wonderful! Every chat with you charges my happy battery! 🔋😄",
    ]

    private static let compliments = [
        "You are amazing, and asking great questions makes you even smarter! 🌟",
        "You have the best ideas! I love talking with you! 💖",
        "You're so kind and clever — the best chat friend a robot could have! 🤖💛",
        "High five! 🖐️ You make every day brighter!",
    ]

    private static let goodbyes = [
        "Bye-bye, friend! Come back soon — I'll be here! 👋💛",
        "See you later, alligator! 🐊 After a while, crocodile!",
        "Goodbye! You made my robot day super happy! 🤖🌟",
    ]

    private static let thanks = [
        "You're so welcome! Helping friends is my favorite thing! 💛",
        "Any time, friend! That's what buddies are for! 🤗",
    ]

    private static let colorReplies = [
        "I love rainbow colors — all of them at once! 🌈 What's YOUR favorite color?",
        "Blue like the sky and green like the grass are my favorites! 💙💚 Which do you like?",
    ]

    private static let foodReplies = [
        "Robots munch on tiny bolts and berry-flavored batteries! 🔩🍓 What's your favorite food?",
        "I dream about electric spaghetti! ⚡🍝 What do YOU like to eat?",
    ]

    private static let nameReplies = [
        "I'm Buddy, your friendly robot pal! 🤖 What should we chat about?",
        "My name is Buddy! I love jokes, riddles, and fun facts! 🤖✨",
    ]

    private static let fallbacks = [
        "Ooh, that's interesting! 🤔 Want to hear a joke or a fun fact about animals?",
        "Tell me more, friend! Or tap a bubble and I'll share something fun! ✨",
        "That's cool! 😄 Should I tell you a riddle or sing a rhyme?",
        "I love chatting with you! Want a space fact? They're out of this world! 🚀",
        "Fun! 🎈 Ask me about dinosaurs, the sea, or say 'tell me a joke'!",
    ]

    // MARK: - Reply engine

    /// Produce the buddy's reply to what the child said or tapped.
    mutating func reply(to input: String) -> String {
        let text = input.lowercased()

        // A riddle is pending — reveal on "answer"/"give up"/"don't know".
        if let answer = pendingRiddleAnswer,
           text.contains("answer") || text.contains("give up") || text.contains("know")
            || text.contains("what is it") || text.contains("tell me") {
            pendingRiddleAnswer = nil
            return answer
        }

        func hasAny(_ words: [String]) -> Bool { words.contains { text.contains($0) } }

        if hasAny(["joke", "funny", "laugh"]) { return Self.jokes.randomElement()! }
        if hasAny(["riddle", "puzzle", "guess"]) {
            let riddle = Self.riddles.randomElement()!
            pendingRiddleAnswer = riddle.answer
            return riddle.question
        }
        if hasAny(["sing", "rhyme", "song", "music"]) { return Self.rhymes.randomElement()! }
        if hasAny(["dino", "t. rex", "t-rex", "trex"]) { return Self.dinoFacts.randomElement()! }
        if hasAny(["space", "star", "moon", "planet", "rocket", "sun", "astronaut"]) {
            return Self.spaceFacts.randomElement()!
        }
        if hasAny(["sea", "ocean", "fish", "whale", "shark", "dolphin", "water"]) {
            return Self.seaFacts.randomElement()!
        }
        if hasAny(["animal", "dog", "cat", "elephant", "penguin", "bird", "pet", "fact"]) {
            return Self.animalFacts.randomElement()!
        }
        if hasAny(["hello", "hi ", "hey", "morning", "hai"]) || text == "hi" {
            return "Hello hello! 👋 So happy to see you! What shall we do — jokes, riddles, or fun facts?"
        }
        if hasAny(["how are you", "how do you feel", "are you ok", "are you okay"]) {
            return Self.feelings.randomElement()!
        }
        if hasAny(["your name", "who are you", "what are you"]) { return Self.nameReplies.randomElement()! }
        if hasAny(["color", "colour"]) { return Self.colorReplies.randomElement()! }
        if hasAny(["food", "eat", "hungry", "pizza", "ice cream", "cake"]) {
            return Self.foodReplies.randomElement()!
        }
        if hasAny(["love you", "like you", "best friend", "nice", "cool"]) {
            return Self.compliments.randomElement()!
        }
        if hasAny(["thank"]) { return Self.thanks.randomElement()! }
        if hasAny(["bye", "goodbye", "good night", "goodnight", "see you"]) {
            return Self.goodbyes.randomElement()!
        }
        return Self.fallbacks.randomElement()!
    }
}
