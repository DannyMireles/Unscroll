import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// iOS also calls this when `startMonitoring` begins mid-interval. Wiping runtime state here
    /// clears `exceededLockIDs` and breaks shields + notification arming.
    override func intervalDidStart(for activity: DeviceActivityName) {
        guard activity == .unscrollDaily else { return }
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity == .unscrollDaily else { return }

        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let isActualEndOfDay = (hour == 23 && minute >= 58) || hour == 0

        guard isActualEndOfDay else {
            ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
            return
        }

        RuntimeStateStore.save(UnlockRuntimeState())
        ScreenTimeShieldStore.clearAllShields()
        ShieldNotifyFlag.clear()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard activity == .unscrollDaily, let lockID = event.unscrollLockID else { return }

        RuntimeStateStore.update { state in
            state.exceededLockIDs.insert(lockID)
            if !state.hasActiveUnlock(for: lockID) {
                state.temporaryUnlocks.removeValue(forKey: lockID)
                state.unlockGrantedAt.removeValue(forKey: lockID)
            }
        }
        ShieldNotifyFlag.arm()
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }
}
