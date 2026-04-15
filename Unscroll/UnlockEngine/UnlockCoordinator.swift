import Foundation

@MainActor
final class UnlockCoordinator: ObservableObject {
    @Published var activeLock: AppLock?

    private var pendingDeepLinkURL: URL?

    func handle(url: URL, locks: [AppLock]) {
        guard url.scheme == AppConstants.urlScheme else { return }
        guard url.host == "unlock" else { return }

        let idString = url.pathComponents.dropFirst().first
            ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value

        guard let idString else {
            consumePendingUnlock()
            return
        }

        guard let id = UUID(uuidString: idString) else {
            return
        }

        if let lock = locks.first(where: { $0.id == id }) {
            activeLock = lock
        } else if locks.isEmpty {
            pendingDeepLinkURL = url
        } else {
            consumePendingUnlock()
        }
    }

    func processPendingDeepLink(locks: [AppLock]) {
        guard let url = pendingDeepLinkURL else { return }
        pendingDeepLinkURL = nil
        handle(url: url, locks: locks)
    }

    func consumePendingUnlock() {
        let state = RuntimeStateStore.load()

        if state.suppressNextPendingPrompt {
            RuntimeStateStore.update {
                $0.suppressNextPendingPrompt = false
                $0.pendingUnlockTriggered = false
                $0.pendingUnlockLockID = nil
            }
            return
        }

        let locks = SharedLockFileStore.load()

        if let id = state.pendingUnlockLockID, let lock = locks.first(where: { $0.id == id }) {
            activeLock = lock
            return
        }

        if let lock = locks.first(where: {
            !$0.isPaused &&
            state.exceededLockIDs.contains($0.id) &&
            !state.hasActiveUnlock(for: $0.id)
        }) {
            activeLock = lock
            return
        }

        if state.pendingUnlockTriggered {
            RuntimeStateStore.update { $0.pendingUnlockTriggered = false }
        }
    }

    func completeUnlock(for lock: AppLock) async -> Int {
        Haptics.success()
        activeLock = nil
        await RestrictionEngine.shared.grantTemporaryUnlock(for: lock)
        return AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
    }
}
