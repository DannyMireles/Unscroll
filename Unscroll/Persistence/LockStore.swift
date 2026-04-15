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
        name: String,
        launchURLScheme: String?,
        limitMinutes: Int,
        method: UnlockMethod,
        rewardMode: UnlockRewardMode
    ) async {
        let resolvedName = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? Self.displayName(for: selection)
            : name.trimmingCharacters(in: .whitespaces)
        let normalizedScheme = Self.normalizeScheme(launchURLScheme)
        let lock = AppLock(
            selection: selection,
            appDisplayName: resolvedName,
            launchURLScheme: normalizedScheme,
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
        updated.launchURLScheme = Self.normalizeScheme(updated.launchURLScheme)
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

    static func normalizeScheme(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix: String
        if trimmed.lowercased().hasSuffix("://") {
            withoutPrefix = String(trimmed.dropLast(3))
        } else if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            withoutPrefix = trimmed
        } else {
            withoutPrefix = trimmed
        }

        let normalized = withoutPrefix
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
        return normalized.isEmpty ? nil : normalized
    }

    static func suggestedScheme(for appName: String) -> String {
        let normalized = appName.lowercased().filter { $0.isLetter || $0.isNumber }
        if let scheme = popularAppNameToScheme[normalized] {
            return scheme
        }
        let parts = appName.split { !$0.isLetter && !$0.isNumber }
        if let first = parts.first {
            let firstKey = String(first).lowercased().filter { $0.isLetter || $0.isNumber }
            if let scheme = popularAppNameToScheme[firstKey] {
                return scheme
            }
        }
        return normalized
    }

    static func suggestedScheme(for selection: FamilyActivitySelection, fallbackName: String) -> String {
        if let bundleID = inferredBundleID(from: selection),
           let mapped = popularBundleIDToNameAndScheme[bundleID] {
            return mapped.scheme
        }
        return suggestedScheme(for: fallbackName)
    }

    /// Returns a human-readable display name for a selection.
    ///
    /// On iOS 16+, `FamilyActivitySelection.applications` contains `Application` objects
    /// whose `localizedDisplayName` is populated immediately after the user makes a
    /// selection via `FamilyActivityPicker`. Use that when available so the name reflects
    /// the actual app (e.g. "TikTok") rather than a generic placeholder.
    static func displayName(for selection: FamilyActivitySelection) -> String {
        let appNames = selection.applications
            .compactMap(\.localizedDisplayName)
            .sorted()

        if !appNames.isEmpty {
            switch appNames.count {
            case 1: return appNames[0]
            case 2: return "\(appNames[0]) & \(appNames[1])"
            default: return "\(appNames[0]) & \(appNames.count - 1) more"
            }
        }

        if let bundleID = inferredBundleID(from: selection),
           let mapped = popularBundleIDToNameAndScheme[bundleID] {
            return mapped.name
        }

        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        let webDomainCount = selection.webDomainTokens.count
        let totalCount = appCount + categoryCount + webDomainCount

        guard totalCount > 0 else { return "No selection" }

        if categoryCount == 0, webDomainCount == 0 {
            return appCount == 1 ? "Selected app" : "\(appCount) apps"
        }

        if appCount == 0, webDomainCount == 0 {
            return categoryCount == 1 ? "Selected category" : "\(categoryCount) categories"
        }

        if appCount == 0, categoryCount == 0 {
            return webDomainCount == 1 ? "Selected website" : "\(webDomainCount) websites"
        }

        return "\(totalCount) items"
    }

    private static func inferredBundleID(from selection: FamilyActivitySelection) -> String? {
        guard selection.applicationTokens.count == 1,
              selection.categoryTokens.isEmpty,
              selection.webDomainTokens.isEmpty,
              let token = selection.applicationTokens.first
        else {
            return nil
        }

        let tokenDescription = String(describing: token)
        let pattern = #"([A-Za-z0-9]+\.)+[A-Za-z0-9\-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(tokenDescription.startIndex..<tokenDescription.endIndex, in: tokenDescription)
        guard let match = regex.firstMatch(in: tokenDescription, options: [], range: range),
              let matchRange = Range(match.range, in: tokenDescription)
        else {
            return nil
        }
        return String(tokenDescription[matchRange])
    }

    // MARK: - Lock form UX (clear generic auto-fill on focus)

    /// True when the lock name is a Screen Time generic label, not a real app title.
    static func shouldClearLockNameOnFocus(_ name: String) -> Bool {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }

        let exact: Set<String> = [
            "Selected app",
            "Selected category",
            "Selected website",
            "No selection",
        ]
        if exact.contains(t) { return true }

        let countedSuffixes = ["apps", "categories", "websites", "items"]
        for suf in countedSuffixes {
            guard t.hasSuffix(" \(suf)") else { continue }
            let prefix = String(t.dropLast(suf.count + 1))
            if prefix.allSatisfy(\.isNumber), !prefix.isEmpty { return true }
        }

        if t.contains(" & "), t.hasSuffix(" more") { return true }

        return false
    }

    /// True when the scheme is exactly the auto-suggested value (user can tap to replace without backspacing).
    static func shouldClearLaunchSchemeOnFocus(_ scheme: String, selection: FamilyActivitySelection, lockName: String) -> Bool {
        let t = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        let suggested = suggestedScheme(for: selection, fallbackName: lockName)
        return t.caseInsensitiveCompare(suggested) == .orderedSame
    }
}
