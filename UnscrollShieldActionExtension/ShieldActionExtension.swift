import Foundation
import ManagedSettings
import UserNotifications

// Principal class must match `$(PRODUCT_MODULE_NAME).ShieldActionExtension` in Info.plist (no custom `@objc` name).
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        switch action {
        case .primaryButtonPressed:
            let lockID = requestUnlock(matching: { $0.selection.applicationTokens.contains(application) })
            scheduleOpenUnscrollNotification(lockID: lockID, requestID: requestID) {
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        switch action {
        case .primaryButtonPressed:
            let lockID = requestUnlock(matching: { $0.selection.categoryTokens.contains(category) })
            scheduleOpenUnscrollNotification(lockID: lockID, requestID: requestID) {
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        switch action {
        case .primaryButtonPressed:
            let lockID = requestUnlock(matching: { $0.selection.webDomainTokens.contains(webDomain) })
            scheduleOpenUnscrollNotification(lockID: lockID, requestID: requestID) {
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    @discardableResult
    private func requestUnlock(matching predicate: (AppLock) -> Bool) -> UUID? {
        let locks = SharedLockFileStore.load()
        let matchedID = locks.first(where: predicate)?.id
        RuntimeStateStore.update { state in
            state.pendingUnlockTriggered = true
            state.suppressNextPendingPrompt = false
            state.lastShieldAction = .goToActivity
            state.lastShieldActionAt = Date()
            if let id = matchedID {
                state.pendingUnlockLockID = id
            }
        }
        return matchedID
    }

    /// The notification must be scheduled from the action extension, after the user taps
    /// the shield button. Scheduling from the configuration extension fires too early and
    /// is not reliable across the Screen Time sandbox.
    private func scheduleOpenUnscrollNotification(
        lockID: UUID?,
        requestID: String,
        afterScheduled: @escaping () -> Void
    ) {
        let identifier = "unscroll.open.activity.\(requestID)"

        let content = UNMutableNotificationContent()
        content.title = "Complete your activity"
        content.body = "Tap to open Unscroll."
        content.sound = .default

        let deeplink: String
        if let lockID {
            deeplink = "unscroll://unlock?id=\(lockID.uuidString)"
        } else {
            deeplink = "unscroll://unlock"
        }
        content.userInfo = ["deeplink": deeplink]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error {
                NSLog("🔔 Unscroll shield action notification failed %@", String(describing: error))
            } else {
                NSLog("🔔 Unscroll shield action notification scheduled deeplink=%@", deeplink)
            }
            DispatchQueue.main.async {
                afterScheduled()
            }
        }
    }
}
