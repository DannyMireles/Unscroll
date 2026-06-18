import Foundation

enum UnlockMethod: String, Codable, CaseIterable, Identifiable {
    case mentalMath
    case patternMemory
    case breathing
    case reflect
    case read

    var id: String { rawValue }

    /// The exercises a user can choose from when setting up a lock. A lock stores one or more
    /// of these; at unlock time one is picked at random (see `AppLock.resolvedForUnlock()`).
    static let allSelectable: [UnlockMethod] = [.mentalMath, .patternMemory, .breathing, .reflect, .read]

    var title: String {
        switch self {
        case .mentalMath: return "Mental Math"
        case .patternMemory: return "Pattern Memory"
        case .breathing: return "Guided Breathing"
        case .reflect: return "Learn Spanish"
        case .read: return "Read Something"
        }
    }

    var shortTitle: String {
        switch self {
        case .mentalMath: return "Math"
        case .patternMemory: return "Pattern"
        case .breathing: return "Breathing"
        case .reflect: return "Spanish"
        case .read: return "Reading"
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
        case .read:
            return "Read a short, interesting Wikipedia summary."
        }
    }
}
