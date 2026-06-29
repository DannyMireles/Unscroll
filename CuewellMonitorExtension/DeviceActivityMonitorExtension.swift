import DeviceActivity
import Foundation
import UserNotifications

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
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Two distinct triggers reach here:
        //  • the all-day limit was reached for the first time today (.cuewellDaily), or
        //  • an incremental grant window was spent (.unlockWindow), meaning the earned usage
        //    ran out and the app should re-lock.
        let isWindow = activity.cuewellUnlockWindowLockID != nil
        let lockID: UUID?
        if activity == .cuewellDaily {
            lockID = event.cuewellLockID
        } else if let windowLockID = activity.cuewellUnlockWindowLockID {
            lockID = windowLockID
        } else {
            lockID = nil
        }
        guard let lockID else { return }

        var shouldNotify = false
        RuntimeStateStore.update { state in
            if isWindow {
                // The earned usage is spent; this lock re-locks now.
                state.activeIncrementalLockIDs.remove(lockID)
            } else {
                // Daily limit callback. Ignore it while the app is in an active unlock
                // (rest-of-day, or an incremental window the user just earned). This is the
                // fix for the daily event re-firing and re-shielding an app that was unlocked.
                guard !state.isUnlockActive(for: lockID) else { return }
            }

            state.exceededLockIDs.insert(lockID)
            state.temporaryUnlocks.removeValue(forKey: lockID)
            state.unlockGrantedAt.removeValue(forKey: lockID)

            // De-dupe notifications against iOS occasionally delivering this callback twice.
            let now = Date()
            if let last = state.lastLimitNotifiedAt[lockID], now.timeIntervalSince(last) < 60 {
                shouldNotify = false
            } else {
                state.lastLimitNotifiedAt[lockID] = now
                shouldNotify = true
            }
        }
        if shouldNotify {
            scheduleLimitReachedNotification(for: lockID)
        }
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    private func scheduleLimitReachedNotification(for lockID: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Cuewell activity ready"
        content.body = "A locked app reached its limit. Tap to start your unlock activity."
        content.sound = .default
        content.userInfo = ["deeplink": "cuewell://unlock?id=\(lockID.uuidString)"]

        let request = UNNotificationRequest(
            identifier: "cuewell.limit.\(lockID.uuidString).\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Cuewell limit notification failed: %@", String(describing: error))
            } else {
                NSLog("Cuewell limit notification scheduled for lock=%@", lockID.uuidString)
            }
        }
    }
}
