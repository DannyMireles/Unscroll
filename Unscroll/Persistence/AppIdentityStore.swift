import Foundation
import ManagedSettings

/// The real identity of a Screen Time–selected app. `bundleIdentifier` and
/// `localizedDisplayName` are only readable inside entitled Screen Time extensions,
/// so we capture them there and persist them here for the main app to use.
struct ResolvedAppIdentity: Codable, Equatable {
    var bundleID: String?
    var displayName: String?
}

/// Shared (App Group) store of `ApplicationToken` → resolved identity. Written by the
/// Screen Time **ShieldConfiguration** extension (the only place iOS exposes the real
/// bundle id / name) and read by the main app so it can open the correct app after an
/// unlock — no input required from the user.
///
/// Persistence goes through `UserDefaults(suiteName:)` rather than a raw file write,
/// because the UI-rendering extension sandbox (ShieldConfiguration / DeviceActivityReport)
/// is **denied direct file writes** to the App Group container, but is allowed to write via
/// the preferences path. A best-effort file write is also kept so the main app, Monitor,
/// and ShieldAction sandboxes (which can write files) stay interoperable.
enum AppIdentityStore {
    private static let appGroup = "group.com.selerim.unscroll"
    private static let recordsKey = "app-identity-records-v2"
    private static let fileName = "app-identities.json"

    private struct StoredIdentityRecord: Codable, Equatable {
        var tokenData: Data
        var bundleID: String?
        var displayName: String?

        var identity: ResolvedAppIdentity {
            ResolvedAppIdentity(bundleID: bundleID, displayName: displayName)
        }
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func identity(for token: ApplicationToken) -> ResolvedAppIdentity? {
        let records = loadRecords()
        return records.last { record in
            decodedToken(from: record.tokenData) == token
        }?.identity
    }

    static func recordCount() -> Int {
        loadRecords().count
    }

    /// Records (or merges) what we learned about an app. Existing non-empty values are
    /// preserved when a later capture is missing one of the fields.
    static func record(token: ApplicationToken, bundleID: String?, displayName: String?) {
        let cleanBundle = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBundle = !(cleanBundle ?? "").isEmpty
        let hasName = !(cleanName ?? "").isEmpty
        guard hasBundle || hasName else {
            NSLog("🧾 Unscroll identity: skipped record because bundle/name were both nil")
            return
        }
        guard let tokenData = encodedToken(token) else {
            NSLog("🧾 Unscroll identity: failed to encode token for '%@'", cleanName ?? cleanBundle ?? "unknown")
            return
        }

        var records = loadRecords()
        let existingIndex = records.lastIndex { record in
            decodedToken(from: record.tokenData) == token
        }
        let existing = existingIndex.map { records[$0].identity }
        let merged = ResolvedAppIdentity(
            bundleID: hasBundle ? cleanBundle : existing?.bundleID,
            displayName: hasName ? cleanName : existing?.displayName
        )
        guard merged != existing else { return }

        let record = StoredIdentityRecord(
            tokenData: tokenData,
            bundleID: merged.bundleID,
            displayName: merged.displayName
        )
        if let existingIndex {
            records[existingIndex] = record
        } else {
            records.append(record)
        }
        save(records)
        logRoundTripCheck(for: token, source: "record")
    }

    static func logRoundTripCheck(for token: ApplicationToken, source: String) {
        let records = loadRecords()
        let matches = records.filter { record in
            decodedToken(from: record.tokenData) == token
        }
        let identity = matches.last?.identity
        NSLog(
            "🧾 Unscroll identity round-trip [%@] records=%d matches=%d bundle=%@ name=%@",
            source,
            records.count,
            matches.count,
            identity?.bundleID ?? "nil",
            identity?.displayName ?? "nil"
        )
    }

    // MARK: - Storage

    private static func loadRecords() -> [StoredIdentityRecord] {
        var records: [StoredIdentityRecord] = []
        var seen = Set<Data>()

        func merge(_ decoded: [StoredIdentityRecord]) {
            for record in decoded where seen.insert(record.tokenData).inserted {
                records.append(record)
            }
        }

        // Primary: UserDefaults (works across the UI-extension sandbox boundary).
        if let data = defaults?.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([StoredIdentityRecord].self, from: data) {
            merge(decoded)
        }

        // Secondary: the legacy/best-effort file (written by file-capable sandboxes).
        if let url = fileURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([StoredIdentityRecord].self, from: data) {
            merge(decoded)
        }

        return records.filter { decodedToken(from: $0.tokenData) != nil }
    }

    private static func save(_ records: [StoredIdentityRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            NSLog("🧾 Unscroll identity: failed to encode %d record(s)", records.count)
            return
        }

        if let defaults {
            defaults.set(data, forKey: recordsKey)
            NSLog("🧾 Unscroll identity: saved %d record(s) via UserDefaults(%@)", records.count, appGroup)
        } else {
            NSLog("🧾 Unscroll identity: App Group UserDefaults unavailable for %@", appGroup)
        }

        // Best-effort: also write the file. Succeeds in the main app / Monitor / ShieldAction
        // sandboxes; silently denied in UI-extension sandboxes (where UserDefaults is the path).
        if let url = fileURL {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private static func encodedToken(_ token: ApplicationToken) -> Data? {
        try? JSONEncoder().encode(token)
    }

    private static func decodedToken(from data: Data) -> ApplicationToken? {
        try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }
}
