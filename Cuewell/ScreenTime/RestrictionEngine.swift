import DeviceActivity
import FamilyControls
import Foundation

actor RestrictionEngine {
    static let shared = RestrictionEngine()

    private let center = DeviceActivityCenter()

    func configureMonitoring(for locks: [AppLock]) async {
        let activeLocks = locks.filter { !$0.isPaused && $0.hasSelection }
        guard !activeLocks.isEmpty else {
            center.stopMonitoring([.cuewellDaily])
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
            try center.startMonitoring(.cuewellDaily, during: schedule, events: events)
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

    /// Opens one lock by granting more *usage* rather than a stretch of wall-clock time.
    ///
    /// For incremental locks this arms a short-lived per-lock schedule whose threshold is a
    /// *usage* amount, so the lock only re-shields after the user has actually used that much
    /// more time — putting the phone down no longer burns the grant. The all-day limit
    /// threshold is never touched, so each lock stays independent (one unlock can't disturb
    /// another's counter) and the daily reset keeps working untouched.
    func grantTemporaryUnlock(for lock: AppLock) async {
        let now = Date()
        let isRestOfDay = lock.unlockRewardMode == .unlockedRestOfDay

        RuntimeStateStore.update { state in
            // Drop this lock's shield immediately.
            state.exceededLockIDs.remove(lock.id)
            state.pendingUnlockLockID = nil
            state.pendingUnlockTriggered = false
            state.suppressNextPendingPrompt = false

            if isRestOfDay {
                let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
                state.temporaryUnlocks[lock.id] = tomorrow
                state.unlockGrantedAt[lock.id] = now
            } else {
                state.temporaryUnlocks.removeValue(forKey: lock.id)
                state.unlockGrantedAt[lock.id] = now
            }
        }

        if isRestOfDay {
            // No usage window needed; the rest-of-day flag keeps it open until the daily reset.
            center.stopMonitoring([.unlockWindow(lock.id)])
        } else {
            let grantedMinutes = AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
            scheduleUsageWindow(for: lock, minutes: grantedMinutes)
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

    /// Arms a usage-based grant window: a per-lock schedule running from now until end of day
    /// whose single event fires after `minutes` of *additional usage*. When it fires, the
    /// monitor extension re-shields the lock. The schedule is intentionally not registered
    /// with `includesPastActivity`, so only usage that happens after the unlock counts.
    private func scheduleUsageWindow(for lock: AppLock, minutes: Int) {
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = DateComponents(hour: 23, minute: 59, second: 59)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: endOfDay,
            repeats: false
        )

        let granted = max(1, minutes)
        let event = DeviceActivityEvent(
            applications: lock.selection.applicationTokens,
            categories: lock.selection.categoryTokens,
            webDomains: lock.selection.webDomainTokens,
            threshold: DateComponents(hour: granted / 60, minute: granted % 60)
        )

        do {
            try center.startMonitoring(
                .unlockWindow(lock.id),
                during: schedule,
                events: [.lockThreshold(lock.id): event]
            )
        } catch {
            return
        }
    }
}
