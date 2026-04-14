import DeviceActivity
import Foundation

extension DeviceActivityName {
    static let unscrollDaily = Self("unscroll.daily")
}

extension DeviceActivityEvent.Name {
    static func lockThreshold(_ lockID: UUID) -> Self {
        Self("unscroll.lock.\(lockID.uuidString)")
    }

    var unscrollLockID: UUID? {
        let prefix = "unscroll.lock."
        guard rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(prefix.count)))
    }
}
