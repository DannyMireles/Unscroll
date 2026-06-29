import FamilyControls
import Foundation

enum UnlockRewardMode: String, Codable, CaseIterable, Identifiable {
    case incrementalByLimit
    case unlockedRestOfDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .incrementalByLimit:
            return "Incremental Unlocks"
        case .unlockedRestOfDay:
            return "Unlocked Rest of Day"
        }
    }

    var description: String {
        switch self {
        case .incrementalByLimit:
            return "Each completed activity adds another usage increment for everything in this lock."
        case .unlockedRestOfDay:
            return "After one activity, this lock stays open until tomorrow."
        }
    }
}

struct AppLock: Identifiable, Codable, Equatable {
    var id: UUID
    var selection: FamilyActivitySelection
    var appDisplayName: String
    /// Optional explicit URL scheme for opening the target app (e.g. "tiktok", "fb").
    /// If nil, the app falls back to name-based mapping heuristics.
    var launchURLScheme: String?
    /// Optional App Store artwork URL for the locked app, so we can show the real icon
    /// (the Screen Time token only renders a letter placeholder inside the main app).
    var appIconURL: String?
    var dailyLimitMinutes: Int
    /// One or more exercises chosen for this lock. At unlock time one is picked at random
    /// (see `resolvedForUnlock()`). Always kept non-empty and de-duplicated in order.
    var unlockMethods: [UnlockMethod]
    var unlockRewardMode: UnlockRewardMode
    var isPaused: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        selection: FamilyActivitySelection,
        appDisplayName: String,
        launchURLScheme: String? = nil,
        appIconURL: String? = nil,
        dailyLimitMinutes: Int,
        unlockMethods: [UnlockMethod],
        unlockRewardMode: UnlockRewardMode = .incrementalByLimit,
        isPaused: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selection = selection
        self.appDisplayName = appDisplayName
        self.launchURLScheme = launchURLScheme
        self.appIconURL = appIconURL
        self.dailyLimitMinutes = dailyLimitMinutes
        self.unlockMethods = Self.sanitized(unlockMethods)
        self.unlockRewardMode = unlockRewardMode
        self.isPaused = isPaused
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// The first selected exercise — used for compact labels and back-compat encoding.
    var primaryMethod: UnlockMethod {
        unlockMethods.first ?? .read
    }

    /// Picks one of the selected exercises at random. Kept as a fallback; the unlock flow now
    /// lets the user choose when a lock has more than one activity (`ActivityChooserView`).
    func resolvedForUnlock() -> UnlockMethod {
        unlockMethods.randomElement() ?? .read
    }

    /// Keeps the list non-empty and de-duplicated while preserving the user's order.
    private static func sanitized(_ methods: [UnlockMethod]) -> [UnlockMethod] {
        var seen = Set<UnlockMethod>()
        let ordered = methods.filter { seen.insert($0).inserted }
        return ordered.isEmpty ? [.read] : ordered
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case selection
        case appDisplayName
        case launchURLScheme
        case appIconURL
        case dailyLimitMinutes
        case unlockMethod
        case unlockMethods
        case unlockRewardMode
        case isPaused
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        selection = try container.decode(FamilyActivitySelection.self, forKey: .selection)
        appDisplayName = try container.decode(String.self, forKey: .appDisplayName)
        launchURLScheme = try container.decodeIfPresent(String.self, forKey: .launchURLScheme)
        appIconURL = try container.decodeIfPresent(String.self, forKey: .appIconURL)
        dailyLimitMinutes = try container.decode(Int.self, forKey: .dailyLimitMinutes)

        // Decode the methods as raw strings and map each through migration, so locks created
        // before the redesign (whose raw values like "mentalMath"/"reflect" no longer exist as
        // cases) never fail to decode — they migrate to a surviving activity instead.
        if let rawMethods = try container.decodeIfPresent([String].self, forKey: .unlockMethods),
           !rawMethods.isEmpty {
            unlockMethods = Self.sanitized(rawMethods.flatMap { Self.migrate(legacyRaw: $0) })
        } else if let legacyRaw = try container.decodeIfPresent(String.self, forKey: .unlockMethod) {
            unlockMethods = Self.sanitized(Self.migrate(legacyRaw: legacyRaw))
        } else {
            unlockMethods = [.read]
        }

        unlockRewardMode = try container.decodeIfPresent(UnlockRewardMode.self, forKey: .unlockRewardMode) ?? .incrementalByLimit
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(selection, forKey: .selection)
        try container.encode(appDisplayName, forKey: .appDisplayName)
        try container.encodeIfPresent(launchURLScheme, forKey: .launchURLScheme)
        try container.encodeIfPresent(appIconURL, forKey: .appIconURL)
        try container.encode(dailyLimitMinutes, forKey: .dailyLimitMinutes)
        try container.encode(unlockMethods, forKey: .unlockMethods)
        // Back-compat: builds before multi-select read a single `unlockMethod`.
        try container.encode(primaryMethod, forKey: .unlockMethod)
        try container.encode(unlockRewardMode, forKey: .unlockRewardMode)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Maps any stored method raw value — current or legacy — onto the surviving four
    /// activities. Removed exercises fold into their nearest replacement:
    /// breathing/journaling → mindfulness, math → pattern, the languages → read.
    private static func migrate(legacyRaw: String) -> [UnlockMethod] {
        switch legacyRaw {
        case "patternMemory": return [.pattern]
        case "read": return [.read]
        case "mindful": return [.mindful]
        case "outside": return [.outside]
        case "breathing", "journaling": return [.mindful]
        case "mentalMath": return [.pattern]
        case "reflect", "spanish", "french", "german": return [.read]
        case "random": return UnlockMethod.allSelectable
        default: return [UnlockMethod(rawValue: legacyRaw)].compactMap { $0 }
        }
    }

    var limitLabel: String {
        let hours = dailyLimitMinutes / 60
        let minutes = dailyLimitMinutes % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(minutes)m"
        }
    }

    var selectedAppCount: Int {
        selection.applicationTokens.count
    }

    var selectedCategoryCount: Int {
        selection.categoryTokens.count
    }

    var selectedWebDomainCount: Int {
        selection.webDomainTokens.count
    }

    var selectedItemCount: Int {
        selectedAppCount + selectedCategoryCount + selectedWebDomainCount
    }

    var hasSelection: Bool {
        selectedItemCount > 0
    }

    /// True only when the lock targets exactly one app (no categories, no websites). That's
    /// the only case where "open the app" is meaningful — a category or a multi-app lock has
    /// no single app to jump to, so we never offer a deep link for those.
    var canDeepLink: Bool {
        selection.applicationTokens.count == 1
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }
}
