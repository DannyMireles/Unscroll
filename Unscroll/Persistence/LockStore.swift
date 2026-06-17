import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class LockStore: ObservableObject {
    @Published private(set) var locks: [AppLock] = []
    @Published var lastErrorMessage: String?

    func load() async {
        locks = SharedLockFileStore.load()
        reconcileDisplayNames()
    }

    /// Upgrades locks whose name we couldn't read at creation time (e.g. "App")
    /// using the real identity captured by Screen Time extensions. Runs automatically,
    /// so the user never has to type anything.
    func reconcileDisplayNames() {
        var changed = false
        for index in locks.indices {
            let lock = locks[index]
            Self.captureSelectionIdentities(lock.selection, source: "lock.reconcile")
            guard lock.selection.applicationTokens.count == 1,
                  let token = lock.selection.applicationTokens.first,
                  let identity = AppIdentityStore.identity(for: token) else { continue }

            AppIdentityStore.logRoundTripCheck(for: token, source: "lock.reconcile")

            let resolvedName = identity.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let bundleScheme = identity.bundleID.flatMap { Self.launchSchemes(forBundleID: $0).first }

            if Self.isGenericDisplayName(lock.appDisplayName),
               let resolvedName, !resolvedName.isEmpty {
                locks[index].appDisplayName = resolvedName
                changed = true
            }

            let needsScheme = (locks[index].launchURLScheme ?? "").isEmpty
                || Self.isGenericDisplayName(lock.appDisplayName)
            if needsScheme {
                let nameScheme = resolvedName.map { Self.suggestedScheme(for: $0) } ?? ""
                let resolvedScheme = !(bundleScheme ?? "").isEmpty ? bundleScheme : (nameScheme.isEmpty ? nil : nameScheme)
                if let resolvedScheme, resolvedScheme != locks[index].launchURLScheme {
                    locks[index].launchURLScheme = resolvedScheme
                    changed = true
                }
            }
        }

        if changed {
            try? SharedLockFileStore.save(locks)
        }
    }

    @discardableResult
    func add(
        selection: FamilyActivitySelection,
        name: String,
        launchURLScheme: String?,
        limitMinutes: Int,
        method: UnlockMethod,
        rewardMode: UnlockRewardMode
    ) async -> AppLock {
        Self.captureSelectionIdentities(selection, source: "lock.add")
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
        return lock
    }

    func update(_ lock: AppLock) async {
        guard let index = locks.firstIndex(where: { $0.id == lock.id }) else { return }
        var updated = lock
        updated.updatedAt = Date()
        updated.launchURLScheme = Self.normalizeScheme(updated.launchURLScheme)
        locks[index] = updated
        await persistAndRefreshScreenTime()
    }

    @discardableResult
    func resolveAndApplyAppStoreIdentity(lockID: UUID, token: ApplicationToken, name: String) async -> AppLock? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Self.isGenericDisplayName(trimmed),
              let resolved = await Self.resolveAppStoreApp(named: trimmed)
        else { return nil }

        AppIdentityStore.record(
            token: token,
            bundleID: resolved.bundleID,
            displayName: resolved.displayName
        )

        guard let index = locks.firstIndex(where: { $0.id == lockID }) else { return nil }

        let scheme = resolved.launchSchemes.first
            ?? Self.launchSchemes(forBundleID: resolved.bundleID).first
            ?? Self.launchSchemes(forName: resolved.displayName).first
            ?? Self.normalizeScheme(locks[index].launchURLScheme)

        var updated = locks[index]
        let displayName = Self.cleanAppStoreDisplayName(resolved.displayName, fallback: trimmed)
        if !Self.isGenericDisplayName(displayName) {
            updated.appDisplayName = displayName
        }
        updated.launchURLScheme = scheme
        updated.updatedAt = Date()

        guard updated != locks[index] else { return locks[index] }
        locks[index] = updated
        NSLog(
            "🌐 Unscroll App Store resolved '%@' -> bundle=%@ scheme=%@",
            trimmed,
            resolved.bundleID,
            scheme ?? "nil"
        )
        await persistAndRefreshScreenTime()
        return updated
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
            state.incrementalUnlockCounts.removeValue(forKey: lock.id)
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
        // Never derive a launch scheme from an auto-generated placeholder like
        // "App" or "3 apps" — that produced bogus URLs such as `app://`.
        guard !isGenericDisplayName(appName) else { return "" }

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

    /// True when a name is one of the auto-generated placeholders produced by
    /// `displayName(for:)` (e.g. "App", "3 apps", "No selection"). These do
    /// not identify a real app, so they must not be used to build a launch scheme.
    static func isGenericDisplayName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }

        let exactPlaceholders: Set<String> = [
            "app", "chosen app",
            "selected app", "selected category", "selected website",
            "selected apps", "no selection"
        ]
        if exactPlaceholders.contains(trimmed) { return true }

        let parts = trimmed.split(separator: " ")
        if parts.count == 2,
           Int(parts[0]) != nil,
           ["app", "apps", "category", "categories", "website", "websites", "item", "items"].contains(String(parts[1])) {
            return true
        }
        return false
    }

    static func suggestedScheme(for selection: FamilyActivitySelection, fallbackName: String) -> String {
        captureSelectionIdentities(selection, source: "scheme.selection")

        if selection.applicationTokens.count == 1,
           let token = selection.applicationTokens.first,
           let identity = AppIdentityStore.identity(for: token) {
            if let bundleID = identity.bundleID,
               let scheme = launchSchemes(forBundleID: bundleID).first {
                return scheme
            }
            if let displayName = identity.displayName,
               let scheme = launchSchemes(forName: displayName).first {
                return scheme
            }
        }

        if let bundleID = inferredBundleID(from: selection),
           let scheme = launchSchemes(forBundleID: bundleID).first {
            return scheme
        }
        return suggestedScheme(for: fallbackName)
    }

    static func captureSelectionIdentities(_ selection: FamilyActivitySelection, source: String) {
        var captured = 0
        for application in selection.applications {
            guard let token = application.token else { continue }
            let displayName = application.localizedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let bundleID = application.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !(displayName ?? "").isEmpty || !(bundleID ?? "").isEmpty else { continue }
            AppIdentityStore.record(token: token, bundleID: bundleID, displayName: displayName)
            captured += 1
        }

        if !selection.applications.isEmpty || !selection.applicationTokens.isEmpty {
            NSLog(
                "🧾 Unscroll selection identity [%@] applications=%d tokens=%d captured=%d records=%d",
                source,
                selection.applications.count,
                selection.applicationTokens.count,
                captured,
                AppIdentityStore.recordCount()
            )
        }
    }

    /// Returns a human-readable display name for a selection.
    ///
    /// In the main app, Screen Time app names are normally private. Use any identity
    /// already captured by an entitled extension, then fall back to the token label in
    /// UI and a generic stored string for persistence.
    static func displayName(for selection: FamilyActivitySelection) -> String {
        let capturedNames = selection.applicationTokens
            .compactMap { AppIdentityStore.identity(for: $0)?.displayName }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        if !capturedNames.isEmpty,
           capturedNames.count == selection.applicationTokens.count,
           selection.categoryTokens.isEmpty,
           selection.webDomainTokens.isEmpty {
            switch capturedNames.count {
            case 1: return capturedNames[0]
            case 2: return "\(capturedNames[0]) & \(capturedNames[1])"
            default: return "\(capturedNames[0]) & \(capturedNames.count - 1) more"
            }
        }

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
            return appCount == 1 ? "App" : "\(appCount) apps"
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
}
