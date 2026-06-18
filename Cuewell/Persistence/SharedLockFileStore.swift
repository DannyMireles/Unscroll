import Foundation

enum SharedLockFileStore {
    private static let fileName = "locks.json"

    static func load() -> [AppLock] {
        guard let url = AppGroupFile.url(named: fileName) else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        do {
            return try JSONDecoder.cuewell.decode([AppLock].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ locks: [AppLock]) throws {
        guard let url = AppGroupFile.url(named: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder.cuewell.encode(locks)
        try data.write(to: url, options: [.atomic])
    }
}
