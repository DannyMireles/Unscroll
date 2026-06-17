import FamilyControls
import ManagedSettings
import os
import UIKit

enum AppLaunchHelper {
    private static let log = Logger(subsystem: "com.selerim.unscroll", category: "AppLaunch")

    /// Opens the app associated with a lock.
    ///
    /// Resolution order (built in `launchURLCandidates`):
    /// 1. The lock's stored launch scheme — derived from the app name the user confirmed
    ///    in the picker (iOS never hands the selected app's identity to the main app).
    /// 2. Launch-scheme variants for that confirmed display name.
    /// 3. A web universal link as a last resort (opens the installed app via Associated
    ///    Domains, otherwise the website).
    ///
    /// Every custom-scheme candidate is actually attempted via `UIApplication.open` (which
    /// launches an installed app even when the scheme isn't declared); schemes the system
    /// confirms are installed are tried first. If nothing opens — or the lock has no single
    /// app to link to — `onUnavailable` is called.
    @MainActor
    static func openTargetApp(for lock: AppLock, onUnavailable: (() -> Void)? = nil) {
        let candidates = launchURLCandidates(for: lock)
        let summary = candidates.map(\.absoluteString).joined(separator: ", ")
        let displayName = resolvedDisplayName(for: lock)
        log.info("openTargetApp '\(displayName, privacy: .public)' stored=\(lock.launchURLScheme ?? "nil", privacy: .public) candidates=[\(summary, privacy: .public)]")
        NSLog("🔗 Unscroll: open '%@' candidates=[%@]", displayName, summary)

        guard !candidates.isEmpty else {
            NSLog("🔗 Unscroll: no launch candidates for '%@' — opening unavailable", displayName)
            onUnavailable?()
            return
        }

        // A short delay lets ManagedSettings drop the shield before we open the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            attemptOpen(prioritized(candidates), onUnavailable: onUnavailable)
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
