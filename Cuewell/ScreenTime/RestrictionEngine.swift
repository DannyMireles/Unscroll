import DeviceActivity
import FamilyControls
import Foundation

enum ScreenTimeMonitoringError: LocalizedError {
    case dailyMonitoringFailed(underlying: Error)
    case unlockWindowMonitoringFailed(lockName: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .dailyMonitoringFailed:
            return "Cuewell could not start Screen Time monitoring."
        case .unlockWindowMonitoringFailed(let lockName, _):
            return "Cuewell could not unlock \(displayName(lockName))."
        }
    }

    var recoverySuggestion: String? {
        "Open Settings > Screen Time and confirm Cuewell is allowed, then reopen Cuewell."
    }

    var userFacingMessage: String {
        switch self {
        case .dailyMonitoringFailed:
            return "Cuewell could not start Screen Time monitoring. Open Settings > Screen Time and confirm Cuewell is allowed, then reopen Cuewell."
        case .unlockWindowMonitoringFailed(let lockName, _):
            return "Cuewell could not safely start the next \(displayName(lockName)) unlock window, so the lock stayed on. Open Settings > Screen Time and confirm Cuewell is allowed, then try again."
        }
    }

    var likelyNeedsScreenTimeAccessRefresh: Bool {
        guard let underlying else { return false }
        let description = "\(underlying) \((underlying as NSError).localizedDescription)"
            .lowercased()
        return description.contains("authoriz")
            || description.contains("permission")
            || description.contains("entitlement")
            || description.contains("denied")
            || description.contains("family")
    }

    private var underlying: Error? {
        switch self {
        case .dailyMonitoringFailed(let error),
             .unlockWindowMonitoringFailed(_, let error):
            return error
        }
    }

    private func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || isGenericDisplayName(trimmed) ? "app" : trimmed
    }

    private func isGenericDisplayName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["app", "chosen app", "selected app", "selected apps", "no selection"].contains(trimmed) {
            return true
        }

        let parts = trimmed.split(separator: " ")
        if parts.count == 2,
           Int(parts[0]) != nil,
           ["app", "apps", "item", "items"].contains(String(parts[1])) {
            return true
        }
        return false
    }
}

actor RestrictionEngine {
    static let shared = RestrictionEngine()

    private let center = DeviceActivityCenter()

    func configureMonitoring(for locks: [AppLock]) async throws {
        let activeLocks = locks.filter { !$0.isPaused && $0.hasSelection }
        guard !activeLocks.isEmpty else {
            if center.activities.contains(.cuewellDaily) {
                center.stopMonitoring([.cuewellDaily])
            }
            DailyMonitorConfig.clear()
            ScreenTimeShieldStore.clearAllShields()
            return
        }

        // Re-arming the daily schedule restarts its interval, which zeroes the
        // accumulated usage the thresholds count against. Doing that on every app
        // launch/foreground meant the usage limit was never reached, so apps were
        // never shielded. The OS keeps monitoring even while the app is closed, so
        // only (re)start when the configuration actually changed — otherwise leave
        // the existing monitor running untouched.
        let signature = DailyMonitorConfig.signature(for: activeLocks)
        if center.activities.contains(.cuewellDaily),
           DailyMonitorConfig.stored() == signature {
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
            DailyMonitorConfig.save(signature)
        } catch {
            DailyMonitorConfig.clear()
            NSLog("Cuewell Screen Time daily monitoring failed: %@", String(describing: error))
            throw ScreenTimeMonitoringError.dailyMonitoringFailed(underlying: error)
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
    func grantTemporaryUnlock(for lock: AppLock) async throws {
        let now = Date()
        let isRestOfDay = lock.unlockRewardMode == .unlockedRestOfDay

        if !isRestOfDay {
            let grantedMinutes = AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)
            do {
                try scheduleUsageWindow(for: lock, minutes: grantedMinutes)
            } catch {
                await reapplyCurrentShields()
                throw error
            }
        }

        RuntimeStateStore.update { state in
            // Drop this lock's shield only after the next enforcement point is armed.
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
    private func scheduleUsageWindow(for lock: AppLock, minutes: Int) throws {
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
            center.stopMonitoring([.unlockWindow(lock.id)])
            try center.startMonitoring(
                .unlockWindow(lock.id),
                during: schedule,
                events: [.lockThreshold(lock.id): event]
            )
        } catch {
            NSLog("Cuewell Screen Time unlock window failed: %@", String(describing: error))
            throw ScreenTimeMonitoringError.unlockWindowMonitoringFailed(
                lockName: lock.appDisplayName,
                underlying: error
            )
        }
    }
}

/// Tracks the configuration the daily Screen Time monitor was last armed with, so the
/// engine can avoid needlessly restarting it. Restarting resets the usage counters the
/// limit thresholds depend on, which previously kept apps from ever being shielded.
///
/// The signature deliberately keys off each active lock's `updatedAt` rather than the
/// opaque `FamilyActivitySelection`, whose encoding isn't guaranteed to be byte-stable
/// across runs. Every mutation that changes what the monitor should watch (add, edit,
/// limit change, pause/unpause, delete) bumps `updatedAt` or changes the active-lock set,
/// so the signature changes exactly when — and only when — a real re-arm is required.
enum DailyMonitorConfig {
    private static let key = "cuewell.dailyMonitor.signature"

    private struct Entry: Codable {
        let id: UUID
        let limit: Int
        let updatedAt: Date
    }

    static func signature(for activeLocks: [AppLock]) -> Data {
        let entries = activeLocks
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { Entry(id: $0.id, limit: max(1, $0.dailyLimitMinutes), updatedAt: $0.updatedAt) }
        return (try? JSONEncoder().encode(entries)) ?? Data()
    }

    static func stored() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func save(_ data: Data) {
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
