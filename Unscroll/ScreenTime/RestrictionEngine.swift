import DeviceActivity
import FamilyControls
import Foundation

actor RestrictionEngine {
    static let shared = RestrictionEngine()

    private let center = DeviceActivityCenter()
    private var unlockRefreshTask: Task<Void, Never>?

    func configureMonitoring(for locks: [AppLock]) async {
        let activeLocks = locks.filter { !$0.isPaused && $0.hasSelection }
        guard !activeLocks.isEmpty else {
            center.stopMonitoring([.unscrollDaily])
            ScreenTimeShieldStore.clearAllShields()
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for lock in activeLocks {
            if #available(iOS 17.4, *) {
                events[.lockThreshold(lock.id)] = DeviceActivityEvent(
                    applications: lock.selection.applicationTokens,
                    categories: lock.selection.categoryTokens,
                    webDomains: lock.selection.webDomainTokens,
                    threshold: threshold(for: lock.dailyLimitMinutes),
                    includesPastActivity: true
                )
            } else {
                events[.lockThreshold(lock.id)] = DeviceActivityEvent(
                    applications: lock.selection.applicationTokens,
                    categories: lock.selection.categoryTokens,
                    webDomains: lock.selection.webDomainTokens,
                    threshold: threshold(for: lock.dailyLimitMinutes)
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

    func grantTemporaryUnlock(for lock: AppLock) async {
        if lock.unlockRewardMode == .unlockedRestOfDay {
            RuntimeStateStore.update { state in
                state.exceededLockIDs.remove(lock.id)
                state.temporaryUnlocks.removeValue(forKey: lock.id)
                state.unlockGrantedAt.removeValue(forKey: lock.id)
                state.pendingUnlockLockID = nil
                state.pendingUnlockTriggered = false
                state.suppressNextPendingPrompt = false
            }
            await reapplyCurrentShields()
            return
        }

        let grantedMinutes = AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
        let duration = TimeInterval(grantedMinutes * 60)
        let expiration = Date().addingTimeInterval(duration)
        RuntimeStateStore.update { state in
            state.temporaryUnlocks[lock.id] = expiration
            state.unlockGrantedAt.removeValue(forKey: lock.id)
            state.pendingUnlockLockID = nil
            state.pendingUnlockTriggered = false
            state.suppressNextPendingPrompt = false
        }
        await reapplyCurrentShields()
        scheduleShieldRefresh(after: duration + 0.5)
    }

    func clearDailyRuntimeState() async {
        RuntimeStateStore.save(UnlockRuntimeState())
        await reapplyCurrentShields()
    }

    func reapplyCurrentShields() async {
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    private func threshold(for minutes: Int) -> DateComponents {
        DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    private func scheduleShieldRefresh(after delay: TimeInterval) {
        unlockRefreshTask?.cancel()
        unlockRefreshTask = Task {
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            RuntimeStateStore.update { state in
                state.removeExpiredUnlocks()
            }
            await self.reapplyCurrentShields()
        }
    }
}
