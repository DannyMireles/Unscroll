import Foundation

@MainActor
final class UnlockCoordinator: ObservableObject {
    @Published var activeLock: AppLock?
    private let logPrefix = "[UnscrollDebug][UnlockCoordinator]"

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    func handle(url: URL, locks: [AppLock]) {
        guard url.scheme == AppConstants.urlScheme else { return }
        guard url.host == "unlock" else { return }
        log("handle(url:): url=\(url.absoluteString), locksCount=\(locks.count)")

        let idString = url.pathComponents.dropFirst().first
            ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value

        guard let idString else {
            log("handle(url:): missing id")
            return
        }
        guard let id = UUID(uuidString: idString) else {
            log("handle(url:): invalid UUID idString=\(idString)")
            return
        }
        guard let lock = locks.first(where: { $0.id == id }) else {
            log("handle(url:): lock not found for id=\(id.uuidString)")
            return
        }

        activeLock = lock
        log("handle(url:): set activeLock id=\(lock.id.uuidString)")
    }

    /// Reads directly from disk so it is never blocked by the in-memory store's load timing.
    /// Uses `pendingUnlockLockID` when available, then falls back to the first exceeded lock
    /// that is currently blocked (no active unlock). This guarantees the activity appears
    /// even if the shield extension does not persist pending state.
    func consumePendingUnlock() {
        let state = RuntimeStateStore.load()
        log("consumePendingUnlock: state=\(state.debugSummary)")

        if state.suppressNextPendingPrompt {
            RuntimeStateStore.update {
                $0.suppressNextPendingPrompt = false
                $0.pendingUnlockTriggered = false
                $0.pendingUnlockLockID = nil
            }
            log("consumePendingUnlock: suppressNextPendingPrompt=true, cleared and returned")
            return
        }

        let locks = SharedLockFileStore.load()
        log("consumePendingUnlock: loaded locks count=\(locks.count)")

        // Primary: use the specific lock ID stored by the extension.
        if let id = state.pendingUnlockLockID, let lock = locks.first(where: { $0.id == id }) {
            activeLock = lock
            log("consumePendingUnlock: matched pendingUnlockLockID; set activeLock id=\(lock.id.uuidString)")
            return
        }

        // Fallback: always look for a currently blocked exceeded lock.
        if let lock = locks.first(where: {
            !$0.isPaused &&
            state.exceededLockIDs.contains($0.id) &&
            !state.hasActiveUnlock(for: $0.id)
        }) {
            activeLock = lock
            log("consumePendingUnlock: generic fallback matched exceeded lock id=\(lock.id.uuidString)")
            return
        }

        // No matching lock found — clear stale trigger marker so it doesn't linger.
        if state.pendingUnlockTriggered {
            RuntimeStateStore.update { $0.pendingUnlockTriggered = false }
            log("consumePendingUnlock: found no eligible lock; cleared pendingUnlockTriggered")
        }

        log("consumePendingUnlock: no eligible pending/exceeded lock; return")
    }

    func completeUnlock(for lock: AppLock) async -> Int {
        log("completeUnlock: lock id=\(lock.id.uuidString)")
        Haptics.success()
        activeLock = nil
        await RestrictionEngine.shared.grantTemporaryUnlock(for: lock)
        log("completeUnlock: finished grantTemporaryUnlock")
        return AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
    }
}
