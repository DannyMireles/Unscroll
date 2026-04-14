import Foundation

enum AppGroupFile {
    private static let logPrefix = "[UnscrollDebug][AppGroupFile]"

    private static func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    static func containerURL() -> URL? {
        let identifier = AppConstants.appGroupIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )

        if let container {
            log("containerURL: resolved group=\(identifier), bundle=\(bundleID), path=\(container.path)")
            return container
        }

        // Do not silently fall back to Documents; that creates split-brain state where
        // extension writes are invisible to the main app.
        log("containerURL: FAILED group=\(identifier), bundle=\(bundleID)")
        return nil
    }

    static func url(named fileName: String) -> URL? {
        guard let container = containerURL() else { return nil }
        return container.appendingPathComponent(fileName, isDirectory: false)
    }
}
