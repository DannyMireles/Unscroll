import FamilyControls
import Foundation

@MainActor
final class LockStore: ObservableObject {
    @Published private(set) var locks: [AppLock] = []
    @Published var lastErrorMessage: String?

    func load() async {
        locks = SharedLockFileStore.load()
    }

    func add(
        selection: FamilyActivitySelection,
        limitMinutes: Int,
        method: UnlockMethod,
        rewardMode: UnlockRewardMode
    ) async {
        let lock = AppLock(
            selection: selection,
            appDisplayName: Self.displayName(for: selection),
            dailyLimitMinutes: max(1, limitMinutes),
            unlockMethod: method,
            unlockRewardMode: rewardMode
        )
        locks.append(lock)
        await persistAndRefreshScreenTime()
    }

    func update(_ lock: AppLock) async {
        guard let index = locks.firstIndex(where: { $0.id == lock.id }) else { return }
        var updated = lock
        updated.updatedAt = Date()
        locks[index] = updated
        await persistAndRefreshScreenTime()
    }

    func togglePause(_ lock: AppLock) async {
        guard let index = locks.firstIndex(where: { $0.id == lock.id }) else { return }
        locks[index].isPaused.toggle()
        locks[index].updatedAt = Date()
        await persistAndRefreshScreenTime()
    }

    func delete(_ lock: AppLock) async {
        locks.removeAll { $0.id == lock.id }
        RuntimeStateStore.update { state in
            state.exceededLockIDs.remove(lock.id)
            state.temporaryUnlocks.removeValue(forKey: lock.id)
            state.unlockGrantedAt.removeValue(forKey: lock.id)
            if state.pendingUnlockLockID == lock.id {
                state.pendingUnlockLockID = nil
                state.pendingUnlockTriggered = false
                state.suppressNextPendingPrompt = false
            }
        }
        await persistAndRefreshScreenTime()
    }

    private func persistAndRefreshScreenTime() async {
        do {
            try SharedLockFileStore.save(locks)
            lastErrorMessage = nil
            await RestrictionEngine.shared.configureMonitoring(for: locks)
            await RestrictionEngine.shared.reapplyCurrentShields()
        } catch {
            lastErrorMessage = "Your lock changes could not be saved."
        }
    }

    static func displayName(for selection: FamilyActivitySelection) -> String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        let webDomainCount = selection.webDomainTokens.count
        let totalCount = appCount + categoryCount + webDomainCount

        guard totalCount > 0 else { return "No selection" }

        if categoryCount == 0, webDomainCount == 0 {
            return appCount == 1 ? "Selected app" : "\(appCount) selected apps"
        }

        if appCount == 0, webDomainCount == 0 {
            return categoryCount == 1 ? "Selected category" : "\(categoryCount) selected categories"
        }

        if appCount == 0, categoryCount == 0 {
            return webDomainCount == 1 ? "Selected website" : "\(webDomainCount) selected websites"
        }

        return "\(totalCount) selected items"
    }
}
