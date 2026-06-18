import DeviceActivity
import Foundation

extension DeviceActivityName {
    static let cuewellDaily = Self("cuewell.daily")

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
