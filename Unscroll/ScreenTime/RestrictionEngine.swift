import DeviceActivity
import FamilyControls
import Foundation

actor RestrictionEngine {
    static let shared = RestrictionEngine()

    private let center = DeviceActivityCenter()
    private var unlockRefreshTask: Task<Void, Never>?
    private let logPrefix = "[UnscrollDebug][RestrictionEngine]"

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    func configureMonitoring(for locks: [AppLock]) async {
        let activeLocks = locks.filter { !$0.isPaused && $0.hasSelection }
        log("configureMonitoring: locks=\(locks.count), activeLocks=\(activeLocks.count)")
        guard !activeLocks.isEmpty else {
            center.stopMonitoring([.unscrollDaily])
            ScreenTimeShieldStore.clearAllShields()
            log("configureMonitoring: no active locks, stopped monitoring + cleared shields")
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
            log("configureMonitoring: startMonitoring success events=\(events.count)")
        } catch {
            log("configureMonitoring: startMonitoring failed error=\(error)")
            assertionFailure("Failed to start DeviceActivity monitoring: \(error)")
        }
    }

    func markLimitExceeded(for lockID: UUID) async {
        RuntimeStateStore.update { state in
            state.exceededLockIDs.insert(lockID)
            state.temporaryUnlocks.removeValue(forKey: lockID)
            state.unlockGrantedAt.removeValue(forKey: lockID)
        }
        await reapplyCurrentShields()
    }

    func grantTemporaryUnlock(for lock: AppLock) async {
        if lock.unlockRewardMode == .unlockedRestOfDay {
            log("grantTemporaryUnlock: lockID=\(lock.id.uuidString), mode=unlockedRestOfDay")
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
        log("grantTemporaryUnlock: lockID=\(lock.id.uuidString), lockDailyLimit=\(lock.dailyLimitMinutes), grantedMinutes=\(grantedMinutes), expiration=\(expiration)")
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
        log("reapplyCurrentShields")
        ScreenTimeShieldStore.shieldApplications(for: SharedLockFileStore.load())
    }

    private func threshold(for minutes: Int) -> DateComponents {
        DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    private func scheduleShieldRefresh(after delay: TimeInterval) {
        log("scheduleShieldRefresh: delay=\(delay)")
        unlockRefreshTask?.cancel()
        unlockRefreshTask = Task {
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            RuntimeStateStore.update { state in
                state.removeExpiredUnlocks()
            }
            self.log("scheduleShieldRefresh: timer fired, reapplying shields")
            await self.reapplyCurrentShields()
        }
    }
}
