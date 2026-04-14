import Foundation

enum SharedLockFileStore {
    private static let fileName = "locks.json"
    private static let logPrefix = "[UnscrollDebug][SharedLockFileStore]"

    private static func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    static func load() -> [AppLock] {
        guard let url = AppGroupFile.url(named: fileName) else {
            log("load: missing app-group container; returning empty locks")
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }

        do {
            return try JSONDecoder.unscroll.decode([AppLock].self, from: data)
        } catch {
            assertionFailure("Failed to decode locks: \(error)")
            return []
        }
    }

    static func save(_ locks: [AppLock]) throws {
        guard let url = AppGroupFile.url(named: fileName) else {
            log("save: missing app-group container")
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder.unscroll.encode(locks)
        try data.write(to: url, options: [.atomic])
    }
}
