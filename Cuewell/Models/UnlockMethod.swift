import Foundation

/// A single unlock exercise (the "leaf"). Grouped into categories via `ExerciseCategory`.
/// A lock stores one or more of these; one is picked at random per unlock
/// (see `AppLock.resolvedForUnlock()`).
enum UnlockMethod: String, Codable, CaseIterable, Identifiable {
    case mentalMath
    case patternMemory
    case read
    // Raw value kept as "reflect" so locks created before the rename still decode.
    case spanish = "reflect"
    case french
    case german
    case breathing
    case journaling

    var id: String { rawValue }

    /// Everything selectable, ordered by category for the grouped picker.
    static let allSelectable: [UnlockMethod] = ExerciseCategory.allCases.flatMap { $0.exercises }

    var category: ExerciseCategory {
        switch self {
        case .mentalMath, .patternMemory: return .mentalStimulation
        case .read: return .reading
        case .spanish, .french, .german: return .language
        case .breathing, .journaling: return .wellness
        }
    }

    var title: String {
        switch self {
        case .mentalMath: return "Mental Math"
        case .patternMemory: return "Pattern Memory"
        case .read: return "Read Something"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .breathing: return "Guided Breathing"
        case .journaling: return "Journaling"
        }
    }

    var shortTitle: String {
        switch self {
        case .mentalMath: return "Math"
        case .patternMemory: return "Pattern"
        case .read: return "Reading"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .breathing: return "Breathing"
        case .journaling: return "Journaling"
        }
    }

    var description: String {
        switch self {
        case .mentalMath:
            return "Solve a quick arithmetic or number-pattern prompt."
        case .patternMemory:
            return "Watch and repeat a short pattern on a grid."
        case .read:
            return "Read a short, interesting Wikipedia summary."
        case .spanish:
            return "Pick the meaning of one Spanish word."
        case .french:
            return "Pick the meaning of one French word."
        case .german:
            return "Pick the meaning of one German word."
        case .breathing:
            return "Take three guided breaths."
        case .journaling:
            return "Pause on a short reflection prompt."
        }
    }
}

/// The four top-level areas a user picks from. Each owns a set of `UnlockMethod` leaves.
enum ExerciseCategory: String, CaseIterable, Identifiable {
    case mentalStimulation
    case reading
    case language
    case wellness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mentalStimulation: return "Mental Stimulation"
        case .reading: return "Reading"
        case .language: return "Language"
        case .wellness: return "Wellness"
        }
    }

    var subtitle: String {
        switch self {
        case .mentalStimulation: return "Math and pattern memory"
        case .reading: return "A short, interesting read"
        case .language: return "Spanish, French, or German"
        case .wellness: return "Breathing and journaling"
        }
    }

    var systemImage: String {
        switch self {
        case .mentalStimulation: return "brain.head.profile"
        case .reading: return "book.fill"
        case .language: return "character.bubble.fill"
        case .wellness: return "wind"
        }
    }

    /// The sub-exercises shown under this category.
    var exercises: [UnlockMethod] {
        switch self {
        case .mentalStimulation: return [.mentalMath, .patternMemory]
        case .reading: return [.read]
        case .language: return [.spanish, .french, .german]
        case .wellness: return [.breathing, .journaling]
        }
    }
}
