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
    private let logPrefix = "[UnscrollDebug][UnscrollApp]"

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(lockStore)
                .environmentObject(permissionManager)
                .environmentObject(unlockCoordinator)
                .task {
                    log("startup task begin")
                    notificationRouter.install()
                    await requestNotificationPermissionIfNeeded()
                    await lockStore.load()
                    log("lockStore.load complete; locksCount=\(lockStore.locks.count)")
                    await permissionManager.refreshStatus(reason: "app launch")
                    log("permission refresh complete (app launch)")
                    await RestrictionEngine.shared.configureMonitoring(for: lockStore.locks)
                    log("configureMonitoring complete")
                    unlockCoordinator.consumePendingUnlock()
                    log("consumePendingUnlock called from startup task")
                }
                .onChange(of: scenePhase) { newPhase in
                    log("scenePhase changed -> \(String(describing: newPhase))")
                    guard newPhase == .active else { return }
                    Task {
                        log("scene active task begin")
                        await permissionManager.refreshStatus(reason: "scene active")
                        log("permission refresh complete (scene active)")
                        await RestrictionEngine.shared.reapplyCurrentShields()
                        log("reapplyCurrentShields complete (scene active)")
                        unlockCoordinator.consumePendingUnlock()
                        log("consumePendingUnlock called from scene active task")
                    }
                }
                .onOpenURL { url in
                    log("onOpenURL: \(url.absoluteString)")
                    unlockCoordinator.handle(url: url, locks: lockStore.locks)
                }
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else {
                log("notification permission status=\(settings.authorizationStatus.rawValue)")
                return
            }
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            log("notification permission requested, granted=\(granted)")
        } catch {
            log("notification permission request failed: \(error)")
        }
    }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let logPrefix = "[UnscrollDebug][NotificationRouter]"

    func install() {
        UNUserNotificationCenter.current().delegate = self
        NSLog("\(logPrefix) install: delegate set")
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

        NSLog("\(logPrefix) didReceive: opening deeplink=\(deepLink)")
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }
}
