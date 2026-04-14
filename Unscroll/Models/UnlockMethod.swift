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
            return "Solve one calm arithmetic prompt."
        case .patternMemory:
            return "Repeat a short sequence on a 3x3 grid."
        case .breathing:
            return "Take three guided breaths."
        case .reflect:
            return "Learn and answer one Spanish word challenge."
        case .random:
            return "Randomly choose any unlock each time."
        }
    }

    func resolvedForUnlock() -> UnlockMethod {
        guard self == .random else { return self }
        return Self.challengeMethods.randomElement() ?? .mentalMath
    }
}
