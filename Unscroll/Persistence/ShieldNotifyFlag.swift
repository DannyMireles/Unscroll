import Foundation

/// Shared between Device Activity monitor and Shield Configuration extension.
/// Arms when a lock threshold is reached; consumed when the shield UI is built so we only notify for real shield appearances.
enum ShieldNotifyFlag {
    private static let appGroup = "group.com.selerim.unscroll"
    private static let fileName = "pending-shield-open-notification.flag"

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static var isPending: Bool {
        guard let url = fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func arm() {
        guard let url = fileURL else { return }
        try? Data().write(to: url, options: .atomic)
    }

    /// Returns true once per armed cycle; deletes the flag so duplicate shield configuration passes do not re-notify.
    static func consumeIfArmed() -> Bool {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    static func clear() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
