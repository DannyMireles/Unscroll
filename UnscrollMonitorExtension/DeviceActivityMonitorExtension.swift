import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logPrefix = "[UnscrollDebug][DeviceActivityMonitorExtension]"

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    /// iOS also calls this when `startMonitoring` begins mid-interval. Wiping runtime state here
    /// clears `exceededLockIDs` and breaks shields + notification arming.
    override func intervalDidStart(for activity: DeviceActivityName) {
        guard activity == .unscrollDaily else { return }
        log("intervalDidStart: refresh shields only (do not wipe runtime state)")
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity == .unscrollDaily else { return }
        log("intervalDidEnd: reset daily runtime state")
        RuntimeStateStore.save(UnlockRuntimeState())
        ScreenTimeShieldStore.clearAllShields()
        ShieldNotifyFlag.clear()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard activity == .unscrollDaily, let lockID = event.unscrollLockID else { return }

        log("eventDidReachThreshold: lockID=\(lockID.uuidString)")
        RuntimeStateStore.update { state in
            state.exceededLockIDs.insert(lockID)
            state.temporaryUnlocks.removeValue(forKey: lockID)
            state.unlockGrantedAt.removeValue(forKey: lockID)
        }
        ShieldNotifyFlag.arm()
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }
}
