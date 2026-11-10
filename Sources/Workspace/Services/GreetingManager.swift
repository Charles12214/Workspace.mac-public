import SwiftUI
import Combine

@MainActor
public final class GreetingManager: ObservableObject {
    public static let shared = GreetingManager()
    
    public static let greetingsTemplates: [String] = [
        "What's the groove, [name]?",
        "How's it going, [name]?",
        "Ready to build something amazing, [name]?",
        "What are we dreaming up today, [name]?",
        "Let's make some magic happen, [name]!",
        "Good vibes only today, [name] ✨",
        "What's on the agenda, [name]?",
        "Time to shine, [name]!",
        "Workspace is primed and ready, [name].",
        "Let's get down to business, [name]!",
        "Great things start with a single spark, [name].",
        "What's cooking in your workspace, [name]?",
        "Ideas are waiting to fly, [name] 🚀",
        "Welcome back to your command center, [name].",
        "Let's turn coffee into masterpieces, [name] ☕️",
        "Big plans today, [name]?",
        "The stage is yours, [name].",
        "Ready for your next breakthrough, [name]?",
        "Hey [name], let's conquer that to-do list!",
        "Workspace at your fingertips, [name].",
        "What exciting project is next, [name]?",
        "Let's craft something brilliant, [name]!",
        "A fresh canvas awaits, [name].",
        "Smooth sailing ahead, [name] 🌊",
        "Ready to collaborate and create, [name]?",
        "Hello [name]! What's the master plan?",
        "In the flow and in the zone, [name].",
        "All your Workspace superpowers are active, [name] ⚡️",
        "New day, endless possibilities, [name].",
        "What will you bring to life today, [name]?",
        "Speed, focus, and clarity for you today, [name].",
        "Here to make work feel effortless, [name].",
        "Let's make waves today, [name]!",
        "Your productive oasis is ready, [name] 🌴",
        "Let's spark some innovation, [name] ✨",
        "Step into greatness today, [name].",
        "Ready when you are, Captain [name]!",
        "Let's turn inspiration into impact, [name].",
        "Everything you need in one glass pane, [name].",
        "Time to write the next chapter, [name].",
        "Feeling unstoppable today, [name]?",
        "What bold ideas shall we explore, [name]?",
        "Powering up your workspace workflow, [name]!",
        "Let's turn momentum into milestones, [name] 🎯",
        "Creativity unlocked and ready, [name].",
        "Welcome aboard, [name] — let's fly!",
        "Another day to innovate, [name].",
        "Ready to brainstorm and build, [name]?",
        "Productivity mode: Engaged, [name] 🔥",
        "What's your next big win going to be, [name]?"
    ]
    
    @Published public private(set) var currentIndex: Int = 0
    @Published public private(set) var animationTrigger: UUID = UUID()
    
    public init() {
        self.currentIndex = Int.random(in: 0..<Self.greetingsTemplates.count)
    }
    
    public func currentGreeting(for name: String) -> String {
        let template = Self.greetingsTemplates[currentIndex % Self.greetingsTemplates.count]
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "friend" : name
        return template.replacingOccurrences(of: "[name]", with: displayName)
    }
    
    public func shuffleGreeting() {
        var newIndex: Int
        repeat {
            newIndex = Int.random(in: 0..<Self.greetingsTemplates.count)
        } while newIndex == currentIndex && Self.greetingsTemplates.count > 1
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            self.currentIndex = newIndex
            self.animationTrigger = UUID()
        }
    }
}
