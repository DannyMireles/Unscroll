import Foundation

enum AppGroupFile {
    static func containerURL() -> URL? {
        let identifier = AppConstants.appGroupIdentifier
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
        return container
    }

    static func url(named fileName: String) -> URL? {
        guard let container = containerURL() else { return nil }
        return container.appendingPathComponent(fileName, isDirectory: false)
    }
}
