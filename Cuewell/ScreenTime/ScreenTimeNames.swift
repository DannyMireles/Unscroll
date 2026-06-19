import DeviceActivity
import Foundation

extension DeviceActivityName {
    /// All-day schedule that tracks each lock's daily usage limit. Its per-lock thresholds
    /// never change once registered, so the `repeats: true` schedule resets them cleanly at
    /// midnight every day — there is no stale state to carry into a new day.
    static let cuewellDaily = Self("cuewell.daily")

    /// A short-lived, per-lock schedule started when a lock is unlocked. It carries a single
    /// *usage* threshold (see `RestrictionEngine.grantTemporaryUnlock`) so the lock re-shields
    /// after that much additional use rather than after a stretch of wall-clock time.
    static func unlockWindow(_ lockID: UUID) -> Self {
        Self("cuewell.unlock.\(lockID.uuidString)")
    }

    var cuewellUnlockWindowLockID: UUID? {
        let prefix = "cuewell.unlock."
        guard rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(prefix.count)))
    }
}

extension DeviceActivityEvent.Name {
    static func lockThreshold(_ lockID: UUID) -> Self {
        Self("cuewell.lock.\(lockID.uuidString)")
    }

    var cuewellLockID: UUID? {
        let prefix = "cuewell.lock."
        guard rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(prefix.count)))
    }
}
