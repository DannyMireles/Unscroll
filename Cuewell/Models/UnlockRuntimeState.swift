import Foundation

struct UnlockRuntimeState: Codable, Equatable {
    enum ShieldActionKind: String, Codable {
        case goToActivity
        case notNow
    }

    var exceededLockIDs: Set<UUID> = []
    var temporaryUnlocks: [UUID: Date] = [:]
    var unlockGrantedAt: [UUID: Date] = [:]
    var incrementalUnlockCounts: [UUID: Int] = [:]
    var pendingUnlockLockID: UUID?
    /// Set to true by the shield extension whenever the user taps "Go To Activity",
    /// even when the extension cannot match the specific lock by token.
    var pendingUnlockTriggered: Bool = false
    /// Set by "Not Now" so opening Cuewell does not auto-present an activity sheet.
    var suppressNextPendingPrompt: Bool = false
    var lastShieldAction: ShieldActionKind?
    var lastShieldActionAt: Date?
    /// Start-of-day this daily state belongs to. Used to lazily reset the limit state
    /// when a new day begins, so a shield from yesterday never carries over into today
    /// even if the device missed the end-of-day Device Activity callback.
    var dayStart: Date?

    func hasActiveUnlock(for lockID: UUID, now: Date = Date()) -> Bool {
        guard let expiration = temporaryUnlocks[lockID] else { return false }
        return expiration > now
    }

    mutating func removeExpiredUnlocks(now: Date = Date()) {
        let expired = temporaryUnlocks.filter { _, expiration in expiration <= now }
        for lockID in expired.keys {
            temporaryUnlocks.removeValue(forKey: lockID)
            unlockGrantedAt.removeValue(forKey: lockID)
        }
    }

    /// Clears all per-day limit state when the calendar day has rolled over. Returns
    /// `true` when a reset actually happened so callers can persist the fresh state.
    /// This is the authoritative daily reset: it does not rely on a single end-of-day
    /// Device Activity callback firing, so apps can never stay shielded into a new day
    /// without the usage limit being reached again.
    mutating func resetForNewDayIfNeeded(now: Date = Date()) -> Bool {
        let today = Calendar.current.startOfDay(for: now)
        guard let storedDayStart = dayStart else {
            dayStart = today
            return true
        }

        guard storedDayStart != today else { return false }

        exceededLockIDs = []
        temporaryUnlocks = [:]
        unlockGrantedAt = [:]
        incrementalUnlockCounts = [:]
        pendingUnlockLockID = nil
        pendingUnlockTriggered = false
        suppressNextPendingPrompt = false
        lastShieldAction = nil
        lastShieldActionAt = nil
        dayStart = today
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case exceededLockIDs
        case temporaryUnlocks
        case unlockGrantedAt
        case incrementalUnlockCounts
        case pendingUnlockLockID
        case pendingUnlockTriggered
        case suppressNextPendingPrompt
        case lastShieldAction
        case lastShieldActionAt
        case dayStart
    }

    init(
        exceededLockIDs: Set<UUID> = [],
        temporaryUnlocks: [UUID: Date] = [:],
        unlockGrantedAt: [UUID: Date] = [:],
        incrementalUnlockCounts: [UUID: Int] = [:],
        pendingUnlockLockID: UUID? = nil,
        pendingUnlockTriggered: Bool = false,
        suppressNextPendingPrompt: Bool = false,
        lastShieldAction: ShieldActionKind? = nil,
        lastShieldActionAt: Date? = nil,
        dayStart: Date? = nil
    ) {
        self.exceededLockIDs = exceededLockIDs
        self.temporaryUnlocks = temporaryUnlocks
        self.unlockGrantedAt = unlockGrantedAt
        self.incrementalUnlockCounts = incrementalUnlockCounts
        self.pendingUnlockLockID = pendingUnlockLockID
        self.pendingUnlockTriggered = pendingUnlockTriggered
        self.suppressNextPendingPrompt = suppressNextPendingPrompt
        self.lastShieldAction = lastShieldAction
        self.lastShieldActionAt = lastShieldActionAt
        self.dayStart = dayStart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exceededLockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .exceededLockIDs) ?? []
        temporaryUnlocks = try container.decodeIfPresent([UUID: Date].self, forKey: .temporaryUnlocks) ?? [:]
        unlockGrantedAt = try container.decodeIfPresent([UUID: Date].self, forKey: .unlockGrantedAt) ?? [:]
        incrementalUnlockCounts = try container.decodeIfPresent([UUID: Int].self, forKey: .incrementalUnlockCounts) ?? [:]
        pendingUnlockLockID = try container.decodeIfPresent(UUID.self, forKey: .pendingUnlockLockID)
        pendingUnlockTriggered = try container.decodeIfPresent(Bool.self, forKey: .pendingUnlockTriggered) ?? false
        suppressNextPendingPrompt = try container.decodeIfPresent(Bool.self, forKey: .suppressNextPendingPrompt) ?? false
        lastShieldAction = try container.decodeIfPresent(ShieldActionKind.self, forKey: .lastShieldAction)
        lastShieldActionAt = try container.decodeIfPresent(Date.self, forKey: .lastShieldActionAt)
        dayStart = try container.decodeIfPresent(Date.self, forKey: .dayStart)
    }
}
