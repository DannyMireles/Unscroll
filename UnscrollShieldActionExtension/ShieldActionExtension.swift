import Foundation
import ManagedSettings
import ManagedSettingsUI
import UserNotifications

@objc(ShieldActionExtension)
final class ShieldActionExtension: ShieldActionDelegate {
    private let logPrefix = "[UnscrollDebug][ShieldActionExtension]"

    override init() {
        super.init()
        log("init: ShieldActionExtension loaded")
    }

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        log("handle(application): requestID=\(requestID), action=\(String(describing: action))")
        switch action {
        case .primaryButtonPressed:
            requestUnlock(matching: { $0.selection.applicationTokens.contains(application) })
            scheduleOpenUnscrollNotification(requestID: requestID) {
                self.log("application primary requestID=\(requestID) -> completion(.close)")
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            // .defer keeps the shield visible; the user presses the home button to leave.
            // .close on secondary appears to open the shielded app — the opposite of intent.
            log("application secondary requestID=\(requestID) -> completion(.defer)")
            completionHandler(.defer)
        @unknown default:
            log("application unknown requestID=\(requestID) -> completion(.none)")
            completionHandler(.none)
        }
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        log("handle(category): requestID=\(requestID), action=\(String(describing: action))")
        switch action {
        case .primaryButtonPressed:
            requestUnlock(matching: { $0.selection.categoryTokens.contains(category) })
            scheduleOpenUnscrollNotification(requestID: requestID) {
                self.log("category primary requestID=\(requestID) -> completion(.close)")
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            log("category secondary requestID=\(requestID) -> completion(.defer)")
            completionHandler(.defer)
        @unknown default:
            log("category unknown requestID=\(requestID) -> completion(.none)")
            completionHandler(.none)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let requestID = UUID().uuidString
        log("handle(webDomain): requestID=\(requestID), action=\(String(describing: action))")
        switch action {
        case .primaryButtonPressed:
            requestUnlock(matching: { $0.selection.webDomainTokens.contains(webDomain) })
            scheduleOpenUnscrollNotification(requestID: requestID) {
                self.log("webDomain primary requestID=\(requestID) -> completion(.close)")
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            log("webDomain secondary requestID=\(requestID) -> completion(.defer)")
            completionHandler(.defer)
        @unknown default:
            log("webDomain unknown requestID=\(requestID) -> completion(.none)")
            completionHandler(.none)
        }
    }

    private func requestUnlock(matching predicate: (AppLock) -> Bool) {
        let locks = SharedLockFileStore.load()
        let matchedID = locks.first(where: predicate)?.id
        log("requestUnlock: loaded locks=\(locks.count), matchedID=\(matchedID?.uuidString ?? "nil")")
        RuntimeStateStore.update { state in
            state.pendingUnlockTriggered = true
            state.suppressNextPendingPrompt = false
            state.lastShieldAction = .goToActivity
            state.lastShieldActionAt = Date()
            if let id = matchedID {
                state.pendingUnlockLockID = id
            }
        }
        let stateAfter = RuntimeStateStore.load()
        log("requestUnlock: stateAfter=\(stateAfter.debugSummary)")
    }

    // Schedules directly without an async permission check — the async getNotificationSettings
    // callback may not complete before the extension process is terminated by iOS.
    private func scheduleOpenUnscrollNotification(requestID: String, completion: @escaping () -> Void) {
        let identifier = "unscroll.open.activity"

        let content = UNMutableNotificationContent()
        content.title = "Complete your activity"
        content.body = "Open Unscroll to unlock the app."
        content.sound = .default

        // 3-second delay ensures the shield has dismissed and the user is on home screen
        // before the banner appears.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request) { error in
            if let error {
                self.log("scheduleNotification requestID=\(requestID): failed error=\(error)")
            } else {
                self.log("scheduleNotification requestID=\(requestID): scheduled ok")
            }
            completion()
        }
    }
}
