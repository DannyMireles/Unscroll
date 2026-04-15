import Foundation

struct UnlockRuntimeState: Codable, Equatable {
    enum ShieldActionKind: String, Codable {
        case goToActivity
        case notNow
    }

    var exceededLockIDs: Set<UUID> = []
    var temporaryUnlocks: [UUID: Date] = [:]
    var unlockGrantedAt: [UUID: Date] = [:]
    var pendingUnlockLockID: UUID?
    /// Set to true by the shield extension whenever the user taps "Go To Activity",
    /// even when the extension cannot match the specific lock by token.
    var pendingUnlockTriggered: Bool = false
    /// Set by "Not Now" so opening Unscroll does not auto-present an activity sheet.
    var suppressNextPendingPrompt: Bool = false
    var lastShieldAction: ShieldActionKind?
    var lastShieldActionAt: Date?

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

    private enum CodingKeys: String, CodingKey {
        case exceededLockIDs
        case temporaryUnlocks
        case unlockGrantedAt
        case pendingUnlockLockID
        case pendingUnlockTriggered
        case suppressNextPendingPrompt
        case lastShieldAction
        case lastShieldActionAt
    }

    init(
        exceededLockIDs: Set<UUID> = [],
        temporaryUnlocks: [UUID: Date] = [:],
        unlockGrantedAt: [UUID: Date] = [:],
        pendingUnlockLockID: UUID? = nil,
        pendingUnlockTriggered: Bool = false,
        suppressNextPendingPrompt: Bool = false,
        lastShieldAction: ShieldActionKind? = nil,
        lastShieldActionAt: Date? = nil
    ) {
        self.exceededLockIDs = exceededLockIDs
        self.temporaryUnlocks = temporaryUnlocks
        self.unlockGrantedAt = unlockGrantedAt
        self.pendingUnlockLockID = pendingUnlockLockID
        self.pendingUnlockTriggered = pendingUnlockTriggered
        self.suppressNextPendingPrompt = suppressNextPendingPrompt
        self.lastShieldAction = lastShieldAction
        self.lastShieldActionAt = lastShieldActionAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exceededLockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .exceededLockIDs) ?? []
        temporaryUnlocks = try container.decodeIfPresent([UUID: Date].self, forKey: .temporaryUnlocks) ?? [:]
        unlockGrantedAt = try container.decodeIfPresent([UUID: Date].self, forKey: .unlockGrantedAt) ?? [:]
        pendingUnlockLockID = try container.decodeIfPresent(UUID.self, forKey: .pendingUnlockLockID)
        pendingUnlockTriggered = try container.decodeIfPresent(Bool.self, forKey: .pendingUnlockTriggered) ?? false
        suppressNextPendingPrompt = try container.decodeIfPresent(Bool.self, forKey: .suppressNextPendingPrompt) ?? false
        lastShieldAction = try container.decodeIfPresent(ShieldActionKind.self, forKey: .lastShieldAction)
        lastShieldActionAt = try container.decodeIfPresent(Date.self, forKey: .lastShieldActionAt)
    }
}
