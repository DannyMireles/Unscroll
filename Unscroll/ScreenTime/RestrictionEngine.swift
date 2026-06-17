import DeviceActivity
import FamilyControls
import Foundation

actor RestrictionEngine {
    static let shared = RestrictionEngine()

    private let center = DeviceActivityCenter()

    func configureMonitoring(for locks: [AppLock]) async {
        let activeLocks = locks.filter { !$0.isPaused && $0.hasSelection }
        guard !activeLocks.isEmpty else {
            center.stopMonitoring([.unscrollDaily])
            ScreenTimeShieldStore.clearAllShields()
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for lock in activeLocks {
            let threshold = threshold(for: lock)
            if #available(iOS 17.4, *) {
                events[.lockThreshold(lock.id)] = DeviceActivityEvent(
                    applications: lock.selection.applicationTokens,
                    categories: lock.selection.categoryTokens,
                    webDomains: lock.selection.webDomainTokens,
                    threshold: threshold,
                    includesPastActivity: true
                )
            } else {
                events[.lockThreshold(lock.id)] = DeviceActivityEvent(
                    applications: lock.selection.applicationTokens,
                    categories: lock.selection.categoryTokens,
                    webDomains: lock.selection.webDomainTokens,
                    threshold: threshold
                )
            }
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(.unscrollDaily, during: schedule, events: events)
        } catch {
            return
        }
    }

    func markLimitExceeded(for lockID: UUID) async {
        RuntimeStateStore.update { state in
            state.exceededLockIDs.insert(lockID)
            if !state.hasActiveUnlock(for: lockID) {
                state.temporaryUnlocks.removeValue(forKey: lockID)
                state.unlockGrantedAt.removeValue(forKey: lockID)
            }
        }
        await reapplyCurrentShields()
    }

    /// Grants a single timed unlock window for one lock. This is the only mechanism
    /// that controls "is this lock open right now"; the daily threshold itself never
    /// changes and daily monitoring is never restarted here. That keeps each lock
    /// independent (TikTok's unlock can't disturb YouTube's counter) and makes the
    /// unlock feel instant.
    func grantTemporaryUnlock(for lock: AppLock) async {
        let now = Date()
        let isRestOfDay = lock.unlockRewardMode == .unlockedRestOfDay
        let expiration: Date
        if isRestOfDay {
            expiration = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        } else {
            let grantedMinutes = AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
            expiration = now.addingTimeInterval(TimeInterval(grantedMinutes * 60))
        }

        RuntimeStateStore.update { state in
            state.exceededLockIDs.insert(lock.id)
            state.temporaryUnlocks[lock.id] = expiration
            state.unlockGrantedAt[lock.id] = now
            state.pendingUnlockLockID = nil
            state.pendingUnlockTriggered = false
            state.suppressNextPendingPrompt = false
        }

        // Rest-of-day windows are cleared by the end-of-day reset, so they don't need
        // their own expiry schedule. Timed windows re-shield when the window closes.
        if !isRestOfDay {
            scheduleUnlockWindow(for: lock.id, until: expiration)
        }
        await reapplyCurrentShields()
    }

    func clearDailyRuntimeState() async {
        RuntimeStateStore.save(UnlockRuntimeState())
        await reapplyCurrentShields()
    }

    func reapplyCurrentShields() async {
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    private func threshold(for lock: AppLock) -> DateComponents {
        let minutes = max(1, lock.dailyLimitMinutes)
        return DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    private func scheduleUnlockWindow(for lockID: UUID, until expiration: Date) {
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: Date()),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: expiration),
            repeats: false
        )

        do {
            try center.startMonitoring(.unlockWindow(lockID), during: schedule)
        } catch {
            return
        }
    }
}
