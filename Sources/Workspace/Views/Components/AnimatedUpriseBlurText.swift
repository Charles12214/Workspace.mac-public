import SwiftUI

// MARK: - Letter-by-Letter Uprise with Blur Decay Animation
public struct AnimatedUpriseBlurText: View {
    public let text: String
    public let font: Font
    public let gradient: LinearGradient?
    public let color: Color?
    public let letterSpacing: CGFloat
    public let baseStaggerDelay: Double
    
    @State private var isVisible: Bool = false
    @State private var triggerId: UUID = UUID()
    
    public init(
        _ text: String,
        font: Font = .system(size: 32, weight: .bold, design: .rounded),
        gradient: LinearGradient? = nil,
        color: Color? = nil,
        letterSpacing: CGFloat = 0.5,
        baseStaggerDelay: Double = 0.024
    ) {
        self.text = text
        self.font = font
        self.gradient = gradient
        self.color = color
        self.letterSpacing = letterSpacing
        self.baseStaggerDelay = baseStaggerDelay
    }
    
    // Words and their global starting character indices for wrapping
    private var wordsWithIndices: [(word: String, startIndex: Int)] {
        var result: [(String, Int)] = []
        let words = text.components(separatedBy: " ")
        var currentIndex = 0
        for word in words {
            result.append((word, currentIndex))
            currentIndex += word.count + 1 // +1 for the space
        }
        return result
    }
    
    public var body: some View {
        // Multi-line word-wrapping container
        WrappingHStack(wordsWithIndices: wordsWithIndices, letterSpacing: letterSpacing, font: font, gradient: gradient, color: color, isVisible: isVisible, baseDelay: baseStaggerDelay)
            .id(triggerId)
            .onAppear {
                triggerAnimation()
            }
            .onChange(of: text) { _, _ in
                triggerAnimation()
            }
    }
    
    private func triggerAnimation() {
        isVisible = false
        triggerId = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// Word wrapping helper for character-level animations
fileprivate struct WrappingHStack: View {
    let wordsWithIndices: [(word: String, startIndex: Int)]
    let letterSpacing: CGFloat
    let font: Font
    let gradient: LinearGradient?
    let color: Color?
    let isVisible: Bool
    let baseDelay: Double
    
    var body: some View {
        // Natural wrapping flow
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(wordsWithIndices.enumerated()), id: \.offset) { wordIdx, item in
                HStack(spacing: letterSpacing) {
                    ForEach(Array(item.word.enumerated()), id: \.offset) { charIdx, char in
                        let globalIndex = item.startIndex + charIdx
                        SingleAnimatedCharacter(
                            char: char,
                            font: font,
                            gradient: gradient,
                            color: color,
                            isVisible: isVisible,
                            delay: Double(globalIndex) * baseDelay
                        )
                    }
                }
                
                // Space between words
                if wordIdx < wordsWithIndices.count - 1 {
                    Text(" ")
                        .font(font)
                }
            }
        }
    }
}

fileprivate struct SingleAnimatedCharacter: View {
    let char: Character
    let font: Font
    let gradient: LinearGradient?
    let color: Color?
    let isVisible: Bool
    let delay: Double
    
    var body: some View {
        Text(String(char))
            .font(font)
            .foregroundStyle(
                gradient != nil
                    ? AnyShapeStyle(gradient!)
                    : (color != nil ? AnyShapeStyle(color!) : AnyShapeStyle(Color.primary))
            )
            .opacity(isVisible ? 1.0 : 0.0)
            .blur(radius: isVisible ? 0 : 8)
            .offset(y: isVisible ? 0 : 18)
            .scaleEffect(isVisible ? 1.0 : 0.88)
            .animation(
                .spring(response: 0.42, dampingFraction: 0.72)
                .delay(delay),
                value: isVisible
            )
    }
}
