import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// iOS also calls this when `startMonitoring` begins mid-interval. Wiping runtime state here
    /// clears `exceededLockIDs` and breaks shields + notification arming.
    override func intervalDidStart(for activity: DeviceActivityName) {
        guard activity == .cuewellDaily || activity.cuewellUnlockWindowLockID != nil else { return }
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        if activity.cuewellUnlockWindowLockID != nil {
            // The grant window's day ended. Anything still owed is handled by the daily reset.
            RuntimeStateStore.update { state in
                state.removeExpiredUnlocks()
            }
            ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
            return
        }

        guard activity == .cuewellDaily else { return }

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
        // The daily limit was reached the first time, or a usage grant window was exhausted.
        // Either way the lock should shield again.
        let lockID: UUID?
        if activity == .cuewellDaily {
            lockID = event.cuewellLockID
        } else if let windowLockID = activity.cuewellUnlockWindowLockID {
            lockID = windowLockID
        } else {
            lockID = nil
        }
        guard let lockID else { return }

        RuntimeStateStore.update { state in
            guard !state.hasActiveUnlock(for: lockID) else { return }
            state.exceededLockIDs.insert(lockID)
            state.temporaryUnlocks.removeValue(forKey: lockID)
            state.unlockGrantedAt.removeValue(forKey: lockID)
        }
        ShieldNotifyFlag.arm()
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }
}
