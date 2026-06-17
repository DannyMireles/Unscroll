import FamilyControls
import ManagedSettings
import os
import UIKit

enum AppLaunchHelper {
    private static let log = Logger(subsystem: "com.selerim.unscroll", category: "AppLaunch")

    /// Opens the app associated with a lock, fully automatically.
    ///
    /// Resolution order:
    /// 1. The real bundle identifier / name captured by the Shield extension (most
    ///    reliable — this is the only place iOS exposes that information).
    /// 2. The lock's stored launch scheme / display name as a fallback.
    ///
    /// Every custom-scheme candidate is actually attempted via `UIApplication.open`
    /// (which launches an installed app even when the scheme isn't declared), and the
    /// schemes the system confirms are installed are tried first. The web link is the
    /// last resort. If absolutely nothing opens, `onUnavailable` is called.
    @MainActor
    static func openTargetApp(for lock: AppLock, onUnavailable: (() -> Void)? = nil) {
        NotificationCenter.default.post(name: .unscrollRefreshIdentityReport, object: nil)
        openTargetApp(for: lock, resolveAttempt: 0, onUnavailable: onUnavailable)
    }

    @MainActor
    private static func openTargetApp(
        for lock: AppLock,
        resolveAttempt: Int,
        onUnavailable: (() -> Void)?
    ) {
        let candidates = launchURLCandidates(for: lock)
        let summary = candidates.map(\.absoluteString).joined(separator: ", ")
        let displayName = resolvedDisplayName(for: lock)
        log.info("openTargetApp '\(displayName, privacy: .public)' attempt=\(resolveAttempt, privacy: .public) stored=\(lock.launchURLScheme ?? "nil", privacy: .public) candidates=[\(summary, privacy: .public)]")
        NSLog("🔗 Unscroll: open '%@' attempt=%d candidates=[%@]", displayName, resolveAttempt, summary)

        guard !candidates.isEmpty else {
            logIdentityState(for: lock, source: "launch.noCandidates.\(resolveAttempt)")

            if needsUserProvidedLinkName(for: lock) {
                NSLog("🔗 Unscroll: no launch candidates for unresolved app token; requesting app name")
                onUnavailable?()
                return
            }

            if shouldRetryIdentityResolution(for: lock, attempt: resolveAttempt) {
                let delay = retryDelay(for: resolveAttempt)
                NSLog("🔗 Unscroll: no launch candidates for '%@'; retrying identity capture in %.1fs", displayName, delay)
                NotificationCenter.default.post(name: .unscrollRefreshIdentityReport, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    openTargetApp(
                        for: lock,
                        resolveAttempt: resolveAttempt + 1,
                        onUnavailable: onUnavailable
                    )
                }
                return
            }

            NSLog("🔗 Unscroll: no launch candidates for '%@'", displayName)
            onUnavailable?()
            return
        }

        // A short delay lets ManagedSettings drop the shield before we open the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            attemptOpen(prioritized(candidates), onUnavailable: onUnavailable)
        }
    }

    private static func shouldRetryIdentityResolution(for lock: AppLock, attempt: Int) -> Bool {
        guard attempt < 3, !lock.selection.applicationTokens.isEmpty else { return false }
        return lock.selection.applicationTokens.contains { AppIdentityStore.identity(for: $0) == nil }
    }

    @MainActor
    private static func needsUserProvidedLinkName(for lock: AppLock) -> Bool {
        lock.selection.applicationTokens.count == 1
            && lock.selection.categoryTokens.isEmpty
            && lock.selection.webDomainTokens.isEmpty
            && LockStore.isGenericDisplayName(lock.appDisplayName)
            && LockStore.normalizeScheme(lock.launchURLScheme) == nil
    }

    private static func retryDelay(for attempt: Int) -> TimeInterval {
        switch attempt {
        case 0: return 0.8
        case 1: return 1.5
        default: return 2.5
        }
    }

    private static func logIdentityState(for lock: AppLock, source: String) {
        NSLog(
            "🔗 Unscroll: identity state [%@] appTokens=%d storedRecords=%d",
            source,
            lock.selection.applicationTokens.count,
            AppIdentityStore.recordCount()
        )
        for token in lock.selection.applicationTokens {
            AppIdentityStore.logRoundTripCheck(for: token, source: source)
        }
    }

    /// Custom schemes the system confirms are installed go first, then the remaining
    /// custom schemes (still worth trying — `open` works even when `canOpenURL` is
    /// blocked), then web links.
    @MainActor
    private static func prioritized(_ urls: [URL]) -> [URL] {
        let confirmed = urls.filter { isCustomScheme($0) && UIApplication.shared.canOpenURL($0) }
        let otherCustom = urls.filter { isCustomScheme($0) && !UIApplication.shared.canOpenURL($0) }
        let web = urls.filter { !isCustomScheme($0) }
        return confirmed + otherCustom + web
    }

    @MainActor
    private static func attemptOpen(_ urls: [URL], onUnavailable: (() -> Void)?) {
        guard let url = urls.first else {
            NSLog("🔗 Unscroll: all launch candidates failed")
            onUnavailable?()
            return
        }
        let remaining = Array(urls.dropFirst())
        UIApplication.shared.open(url, options: [:]) { success in
            NSLog("🔗 Unscroll: tried %@ -> %@", url.absoluteString, success ? "SUCCESS" : "failed")
            if !success {
                attemptOpen(remaining, onUnavailable: onUnavailable)
            }
        }
    }

    private static func isCustomScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme != "http" && scheme != "https"
    }

    /// Ordered, de-duplicated list of URLs to try: custom schemes first, then a web
    /// universal-link fallback.
    @MainActor
    static func launchURLCandidates(for lock: AppLock) -> [URL] {
        var seen = Set<String>()
        var candidates: [URL] = []

        func appendScheme(_ scheme: String) {
            let normalized = LockStore.normalizeScheme(scheme)
            guard let normalized,
                  !normalized.isEmpty,
                  normalized != "http",
                  normalized != "https" else { return }
            appendURL("\(normalized)://")
        }

        func appendURL(_ string: String) {
            guard let url = URL(string: string), seen.insert(string).inserted else { return }
            candidates.append(url)
        }

        var webDomains: [String] = []

        // 1. Best source: the bundle ID / name captured by the Shield extension.
        for token in lock.selection.applicationTokens {
            guard let identity = AppIdentityStore.identity(for: token) else { continue }

            if let bundleID = identity.bundleID {
                for scheme in LockStore.launchSchemes(forBundleID: bundleID) { appendScheme(scheme) }
                if let mapped = LockStore.popularBundleIDToNameAndScheme[bundleID],
                   let domain = LockStore.webDomain(for: mapped.name) { webDomains.append(domain) }
            }

            if let name = identity.displayName {
                for scheme in LockStore.launchSchemes(forName: name) { appendScheme(scheme) }
                if let domain = LockStore.webDomain(for: name) { webDomains.append(domain) }
            }
        }

        // 2. Fallback: the lock's stored explicit scheme and display-name guess.
        appendScheme(lock.launchURLScheme ?? "")
        for scheme in LockStore.launchSchemes(forName: lock.appDisplayName) { appendScheme(scheme) }

        if let domain = LockStore.webDomain(for: lock.appDisplayName) { webDomains.append(domain) }

        // Web universal links last (they open the installed app via Associated Domains
        // when possible, otherwise the website).
        for domain in webDomains {
            appendURL("https://\(domain)")
        }

        return candidates
    }

    @MainActor
    private static func resolvedDisplayName(for lock: AppLock) -> String {
        if !LockStore.isGenericDisplayName(lock.appDisplayName) {
            return lock.appDisplayName
        }

        let names = lock.selection.applicationTokens
            .compactMap { AppIdentityStore.identity(for: $0)?.displayName }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        guard let first = names.first else {
            return LockStore.isGenericDisplayName(lock.appDisplayName) ? "this app" : lock.appDisplayName
        }
        return names.count == 1 ? first : "\(first) & \(names.count - 1) more"
    }
}
