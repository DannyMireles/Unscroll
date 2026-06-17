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
    var dailyLimitMinutes: Int
    var unlockMethod: UnlockMethod
    var unlockRewardMode: UnlockRewardMode
    var isPaused: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        selection: FamilyActivitySelection,
        appDisplayName: String,
        launchURLScheme: String? = nil,
        dailyLimitMinutes: Int,
        unlockMethod: UnlockMethod,
        unlockRewardMode: UnlockRewardMode = .incrementalByLimit,
        isPaused: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selection = selection
        self.appDisplayName = appDisplayName
        self.launchURLScheme = launchURLScheme
        self.dailyLimitMinutes = dailyLimitMinutes
        self.unlockMethod = unlockMethod
        self.unlockRewardMode = unlockRewardMode
        self.isPaused = isPaused
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case selection
        case appDisplayName
        case launchURLScheme
        case dailyLimitMinutes
        case unlockMethod
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
        dailyLimitMinutes = try container.decode(Int.self, forKey: .dailyLimitMinutes)
        unlockMethod = try container.decode(UnlockMethod.self, forKey: .unlockMethod)
        unlockRewardMode = try container.decodeIfPresent(UnlockRewardMode.self, forKey: .unlockRewardMode) ?? .incrementalByLimit
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
