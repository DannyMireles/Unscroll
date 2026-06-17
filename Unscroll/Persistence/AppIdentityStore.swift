import Foundation
import ManagedSettings
import Security

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
/// Persistence tries the shared keychain first, then App Group preferences and a
/// best-effort App Group file. Different Screen Time sandboxes can deny different
/// storage paths, so reads merge every store instead of trusting only one.
enum AppIdentityStore {
    private static let appGroup = "group.com.selerim.unscroll"
    private static let recordsKey = "app-identity-records-v2"
    private static let fileName = "app-identities.json"

    // Shared keychain — reachable across the App/Shield sandbox via securityd, a different
    // daemon than the filesystem/cfprefsd paths that the UI-extension sandbox denies.
    private static let keychainAccessGroup = "GU6G649D6A.com.selerim.unscroll.keychain"
    private static let keychainService = "com.selerim.unscroll.appidentities"
    private static let keychainAccount = "records"

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
        var indexByTokenData: [Data: Int] = [:]

        func merge(_ decoded: [StoredIdentityRecord]) {
            for record in decoded {
                guard decodedToken(from: record.tokenData) != nil else { continue }

                if let index = indexByTokenData[record.tokenData] {
                    let existing = records[index]
                    records[index] = StoredIdentityRecord(
                        tokenData: record.tokenData,
                        bundleID: nonEmpty(record.bundleID) ?? nonEmpty(existing.bundleID),
                        displayName: nonEmpty(record.displayName) ?? nonEmpty(existing.displayName)
                    )
                } else {
                    indexByTokenData[record.tokenData] = records.count
                    records.append(record)
                }
            }
        }

        // Primary: shared keychain (the path we expect the Shield sandbox can actually write).
        if let data = keychainLoad(),
           let decoded = try? JSONDecoder().decode([StoredIdentityRecord].self, from: data) {
            merge(decoded)
        }

        // Secondary: UserDefaults.
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

        return records
    }

    private static func save(_ records: [StoredIdentityRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            NSLog("🧾 Unscroll identity: failed to encode %d record(s)", records.count)
            return
        }

        // Primary: shared keychain (securityd) — expected to work in the Shield sandbox.
        let keychainStatus = keychainSave(data)
        NSLog("🧾 Unscroll identity: keychain save status=%d for %d record(s)", Int(keychainStatus), records.count)

        // Secondary: UserDefaults.
        if let defaults {
            defaults.set(data, forKey: recordsKey)
        }

        // Best-effort: also write the file (works in main app / Monitor / ShieldAction).
        if let url = fileURL {
            try? data.write(to: url, options: [.atomic])
        }
    }

    // MARK: - Keychain

    private static func keychainBaseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: keychainAccessGroup
        ]
    }

    private static func keychainLoad(account: String = keychainAccount) -> Data? {
        var query = keychainBaseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess { return result as? Data }
        return nil
    }

    @discardableResult
    private static func keychainSave(_ data: Data, account: String = keychainAccount) -> OSStatus {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(keychainBaseQuery(account: account) as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = keychainBaseQuery(account: account)
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(addQuery as CFDictionary, nil)
        }
        return updateStatus
    }

    private static func encodedToken(_ token: ApplicationToken) -> Data? {
        try? JSONEncoder().encode(token)
    }

    private static func decodedToken(from data: Data) -> ApplicationToken? {
        try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed ?? "").isEmpty ? nil : trimmed
    }
}
