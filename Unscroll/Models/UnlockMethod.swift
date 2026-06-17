import Foundation

enum UnlockMethod: String, Codable, CaseIterable, Identifiable {
    case mentalMath
    case patternMemory
    case breathing
    case reflect
    case random

    var id: String { rawValue }

    static let challengeMethods: [UnlockMethod] = [.mentalMath, .patternMemory, .breathing, .reflect]

    var title: String {
        switch self {
        case .mentalMath: return "Mental Math"
        case .patternMemory: return "Pattern Memory"
        case .breathing: return "Guided Breathing"
        case .reflect: return "Spanish Word"
        case .random: return "All Methods"
        }
    }

    var shortTitle: String {
        switch self {
        case .mentalMath: return "Math"
        case .patternMemory: return "Pattern"
        case .breathing: return "Breathing"
        case .reflect: return "Spanish"
        case .random: return "All"
        }
    }

    var description: String {
        switch self {
        case .mentalMath:
            return "Solve a quick arithmetic or number-pattern prompt."
        case .patternMemory:
            return "Watch and repeat a short pattern on a grid."
        case .breathing:
            return "Take three guided breaths."
        case .reflect:
            return "Pick the meaning of one Spanish word."
        case .random:
            return "Randomly choose any unlock each time."
        }
    }

    func resolvedForUnlock() -> UnlockMethod {
        guard self == .random else { return self }
        return Self.challengeMethods.randomElement() ?? .mentalMath
    }
}
