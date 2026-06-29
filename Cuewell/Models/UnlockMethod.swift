import Foundation

/// A single unlock activity. A lock stores one or more of these; when the lock is over its
/// limit the user completes one to earn more time. With more than one selected, the user
/// picks which to do at unlock time (see `ActivityChooserView`) rather than getting a random
/// one — the activities are now very different (e.g. "Go Outside" can't be forced at night).
enum UnlockMethod: String, Codable, CaseIterable, Identifiable {
    /// Read a fresh, hand-picked article on a topic the user chose (links out).
    case read
    /// A short free guided meditation or breathwork session (links out).
    case mindful
    /// Step outside and submit a photo, verified on-device.
    case outside
    /// Watch-and-repeat a short pattern on a grid. Raw value kept as "patternMemory" so
    /// locks created before the redesign still decode.
    case pattern = "patternMemory"

    var id: String { rawValue }

    /// Everything a user can pick, in display order.
    static let allSelectable: [UnlockMethod] = allCases

    var title: String {
        switch self {
        case .read: return "Read"
        case .mindful: return "Mindfulness"
        case .outside: return "Go Outside"
        case .pattern: return "Pattern Memory"
        }
    }

    var shortTitle: String {
        switch self {
        case .read: return "Read"
        case .mindful: return "Mindful"
        case .outside: return "Outside"
        case .pattern: return "Pattern"
        }
    }

    /// One compact line used in pickers and onboarding cards.
    var tagline: String {
        switch self {
        case .read: return "Read a fresh article on a topic you choose."
        case .mindful: return "A short guided meditation or breathwork session."
        case .outside: return "Step outside and snap a photo of where you are."
        case .pattern: return "Watch and repeat a short pattern."
        }
    }

    /// Longer purpose copy for the preview / unlock subtitle.
    var description: String {
        switch self {
        case .read:
            return "Open a hand-picked article from today, give it a real read, then continue."
        case .mindful:
            return "Open a free guided session, take a few minutes for yourself, then continue."
        case .outside:
            return "Go outside and take a photo of nature, the sky, or your street. We verify it right on your device."
        case .pattern:
            return "Watch a short sequence light up on a grid, then repeat it from memory."
        }
    }

    var systemImage: String {
        switch self {
        case .read: return "book.fill"
        case .mindful: return "leaf.fill"
        case .outside: return "sun.max.fill"
        case .pattern: return "square.grid.3x3.fill"
        }
    }

    /// Steps shown in the "how it works" preview sheet.
    var howItWorks: [String] {
        switch self {
        case .read:
            return [
                "We pick a fresh article from a topic you chose.",
                "Open it and actually read for a moment.",
                "Come back and continue to earn your time."
            ]
        case .mindful:
            return [
                "We open a free guided meditation or breathwork session.",
                "Take a few minutes for yourself.",
                "Come back and continue to earn your time."
            ]
        case .outside:
            return [
                "Step outside and take a photo of where you are.",
                "Add it from your camera roll.",
                "We check on-device that it's recent and shows the outdoors."
            ]
        case .pattern:
            return [
                "A short pattern lights up on the grid.",
                "Repeat it from memory.",
                "Get it right to earn your time."
            ]
        }
    }

    /// True for activities that hand the user off to external content. These complete on an
    /// honor + dwell basis (we can't verify reading/meditating). `outside` is verified for real.
    var isLinkOut: Bool {
        switch self {
        case .read, .mindful: return true
        case .outside, .pattern: return false
        }
    }
}
