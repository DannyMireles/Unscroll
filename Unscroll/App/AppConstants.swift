import Foundation

enum AppConstants {
    // TODO: Replace this with the App Group configured in the Apple Developer portal.
    static let appGroupIdentifier = "group.com.selerim.unscroll"
    static let urlScheme = "unscroll"
    // Each completed activity grants min(lock limit, maxUnlockMinutesPerActivity).
    static let maxUnlockMinutesPerActivity = 30

    static func grantedMinutes(for dailyLimitMinutes: Int) -> Int {
        min(max(dailyLimitMinutes, 1), maxUnlockMinutesPerActivity)
    }
}
