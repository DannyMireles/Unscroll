import ManagedSettings
import ManagedSettingsUI
import UserNotifications
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        ShieldOpenNotifier.scheduleIfNeeded()
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.90, green: 0.95, blue: 0.93, alpha: 0.82),
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(
                text: "Your limit is active.",
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Open Unscroll to complete your unlock activity.",
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go To Activity",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.33, green: 0.55, blue: 0.52, alpha: 1),
            secondaryButtonLabel: nil
        )
    }
}

private enum ShieldOpenNotifier {
    private static let appGroupID = "group.com.selerim.unscroll"
    private static let lastSentKey = "shield.open.notification.lastSentAt"
    private static let cooldownSeconds: TimeInterval = 20

    static func scheduleIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }

        guard ShieldNotifyFlag.isPending else {
            return
        }

        let now = Date()
        if let lastSent = defaults.object(forKey: lastSentKey) as? Date,
           now.timeIntervalSince(lastSent) < cooldownSeconds {
            return
        }

        guard ShieldNotifyFlag.consumeIfArmed() else {
            return
        }
        defaults.set(now, forKey: lastSentKey)

        let content = UNMutableNotificationContent()
        content.title = "Continue in Unscroll"
        content.body = "Tap to open Unscroll and complete your activity."
        content.sound = .default
        content.userInfo = ["deeplink": "unscroll://unlock"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "unscroll.shield.open",
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        center.getNotificationSettings { _ in
            center.add(request) { _ in }
        }
    }
}
