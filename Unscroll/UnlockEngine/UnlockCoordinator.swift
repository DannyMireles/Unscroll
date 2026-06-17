import Foundation

@MainActor
final class UnlockCoordinator: ObservableObject {
    @Published var activeLock: AppLock?
    @Published var stats: DailyStats = DailyStatsStore.load()

    private var pendingDeepLinkURL: URL?

    func handle(url: URL, locks: [AppLock]) {
        guard url.scheme == AppConstants.urlScheme else { return }
        guard url.host == "unlock" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let idString = url.pathComponents.dropFirst().first
            ?? queryItems
            .first(where: { $0.name == "id" })?
            .value
        let appName = queryItems.first(where: { $0.name == "appName" })?.value
        let bundleID = queryItems.first(where: { $0.name == "bundleID" })?.value

        guard let idString else {
            if locks.isEmpty {
                pendingDeepLinkURL = url
                return
            }

            if let lock = fallbackLockForIdentitylessDeepLink(locks: locks) {
                activeLock = lockWithCapturedIdentity(lock, appName: appName, bundleID: bundleID)
            } else {
                consumePendingUnlock()
            }
            return
        }

        guard let id = UUID(uuidString: idString) else {
            return
        }

        if let lock = locks.first(where: { $0.id == id }) {
            activeLock = lockWithCapturedIdentity(lock, appName: appName, bundleID: bundleID)
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

    private func lockWithCapturedIdentity(_ lock: AppLock, appName: String?, bundleID: String?) -> AppLock {
        guard lock.canDeepLink, let token = lock.selection.applicationTokens.first else {
            return lock
        }

        let cleanName = nonEmpty(appName)
        let cleanBundle = nonEmpty(bundleID)
        guard cleanName != nil || cleanBundle != nil else {
            return lock
        }

        AppIdentityStore.record(token: token, bundleID: cleanBundle, displayName: cleanName)

        var updated = lock
        if let cleanName, !LockStore.isGenericDisplayName(cleanName) {
            updated.appDisplayName = cleanName
        }

        let bundleScheme = cleanBundle.flatMap { LockStore.launchSchemes(forBundleID: $0).first }
        let nameScheme = cleanName.flatMap { LockStore.launchSchemes(forName: $0).first }
        if let resolvedScheme = bundleScheme ?? nameScheme ?? LockStore.normalizeScheme(updated.launchURLScheme) {
            updated.launchURLScheme = resolvedScheme
        }

        persistCapturedIdentityLock(updated)
        NSLog(
            "🔗 Unscroll: captured notification identity id=%@ bundle=%@ name=%@ scheme=%@",
            updated.id.uuidString,
            cleanBundle ?? "nil",
            cleanName ?? "nil",
            updated.launchURLScheme ?? "nil"
        )
        return updated
    }

    private func persistCapturedIdentityLock(_ updated: AppLock) {
        var locks = SharedLockFileStore.load()
        guard let index = locks.firstIndex(where: { $0.id == updated.id }) else { return }
        guard locks[index] != updated else { return }
        locks[index] = updated
        try? SharedLockFileStore.save(locks)
    }

    private func fallbackLockForIdentitylessDeepLink(locks: [AppLock]) -> AppLock? {
        let state = RuntimeStateStore.load()
        if let id = state.pendingUnlockLockID,
           let lock = locks.first(where: { $0.id == id }) {
            return lock
        }

        let activeShielded = locks.filter {
            !$0.isPaused &&
            state.exceededLockIDs.contains($0.id) &&
            !state.hasActiveUnlock(for: $0.id)
        }
        if activeShielded.count == 1 {
            return activeShielded[0]
        }

        return locks.count == 1 ? locks[0] : nil
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed ?? "").isEmpty ? nil : trimmed
    }

    /// Presents an unlock activity ONLY when the user deliberately asked for one by
    /// tapping "Go To Activity" on a shield. We never auto-present just because some
    /// lock happens to be over its limit — that caused the wrong app's activity to
    /// pop up whenever Unscroll was opened for any reason.
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

        // The shield matched a specific lock by token — present exactly that one.
        if let id = state.pendingUnlockLockID,
           let lock = locks.first(where: { $0.id == id }),
           !lock.isPaused,
           !state.hasActiveUnlock(for: lock.id) {
            activeLock = lock
            clearPendingMarkers()
            return
        }

        // The shield was tapped but couldn't resolve the exact lock by token. Fall back
        // to a lock that is currently shielded and still needs an unlock.
        if state.pendingUnlockTriggered,
           let lock = locks.first(where: {
               !$0.isPaused &&
               state.exceededLockIDs.contains($0.id) &&
               !state.hasActiveUnlock(for: $0.id)
           }) {
            activeLock = lock
        }

        // Clear the one-shot markers so re-foregrounding never re-presents on its own.
        if state.pendingUnlockTriggered || state.pendingUnlockLockID != nil {
            clearPendingMarkers()
        }
    }

    private func clearPendingMarkers() {
        RuntimeStateStore.update {
            $0.pendingUnlockTriggered = false
            $0.pendingUnlockLockID = nil
        }
    }

    func completeUnlock(for lock: AppLock) async -> Int {
        Haptics.success()
        activeLock = nil
        await RestrictionEngine.shared.grantTemporaryUnlock(for: lock)
        let granted = AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
        stats = DailyStatsStore.recordSession(minutes: granted)
        return granted
    }

    func refreshStats() {
        stats = DailyStatsStore.load()
    }
}

// MARK: - Daily progress

/// Lightweight, on-device progress that gives the app a sense of reward and reinforces
/// the "train your mind to earn your scroll" angle.
struct DailyStats: Codable, Equatable {
    var dayStart: Date
    var sessionsToday: Int
    var minutesToday: Int
    var streak: Int

    static let empty = DailyStats(dayStart: .distantPast, sessionsToday: 0, minutesToday: 0, streak: 0)
}

enum DailyStatsStore {
    private static let key = "unscroll.daily.stats"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    }

    /// Loads stats normalized for display: today's counters reset on a new day and the
    /// streak is cleared if more than a day has passed since the last completed session.
    static func load() -> DailyStats {
        var stats = loadRaw()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if stats.dayStart == today {
            return stats
        }

        stats.sessionsToday = 0
        stats.minutesToday = 0

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           stats.dayStart == yesterday {
            return stats
        }

        stats.streak = 0
        return stats
    }

    @discardableResult
    static func recordSession(minutes: Int) -> DailyStats {
        var stats = loadRaw()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if stats.dayStart == today {
            stats.sessionsToday += 1
            stats.minutesToday += minutes
        } else {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               stats.dayStart == yesterday {
                stats.streak += 1
            } else {
                stats.streak = 1
            }
            stats.dayStart = today
            stats.sessionsToday = 1
            stats.minutesToday = minutes
        }

        save(stats)
        return stats
    }

    private static func loadRaw() -> DailyStats {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(DailyStats.self, from: data)
        else {
            return .empty
        }
        return stats
    }

    private static func save(_ stats: DailyStats) {
        guard let defaults, let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: key)
    }
}
