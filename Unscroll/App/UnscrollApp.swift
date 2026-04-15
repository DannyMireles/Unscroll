import SwiftUI
import UserNotifications
import UIKit

@main
struct UnscrollApp: App {
    @StateObject private var lockStore = LockStore()
    @StateObject private var permissionManager = ScreenTimePermissionManager()
    @StateObject private var unlockCoordinator = UnlockCoordinator()
    private let notificationRouter = NotificationRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(lockStore)
                .environmentObject(permissionManager)
                .environmentObject(unlockCoordinator)
                .task {
                    notificationRouter.install()
                    await requestNotificationPermissionIfNeeded()
                    await lockStore.load()
                    unlockCoordinator.processPendingDeepLink(locks: lockStore.locks)
                    await permissionManager.refreshStatus(reason: "app launch")
                    await RestrictionEngine.shared.configureMonitoring(for: lockStore.locks)
                    unlockCoordinator.consumePendingUnlock()
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await permissionManager.refreshStatus(reason: "scene active")
                        await RestrictionEngine.shared.reapplyCurrentShields()
                        unlockCoordinator.consumePendingUnlock()
                    }
                }
                .onOpenURL { url in
                    unlockCoordinator.handle(url: url, locks: lockStore.locks)
                }
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else {
                return
            }
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return
        }
    }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard
            let deepLink = response.notification.request.content.userInfo["deeplink"] as? String,
            let url = URL(string: deepLink)
        else {
            return
        }

        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }
}
