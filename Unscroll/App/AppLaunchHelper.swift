import UIKit

enum AppLaunchHelper {
    /// Opens the app associated with a lock using the stored URL scheme or known name/bundle mappings.
    ///
    /// ManagedSettings shield removal can lag slightly; a short delay improves launch reliability.
    @MainActor
    static func openTargetApp(for lock: AppLock) {
        let explicitScheme = LockStore.normalizeScheme(lock.launchURLScheme)
        let mappedScheme = LockStore.suggestedScheme(for: lock.appDisplayName)
        let scheme = explicitScheme ?? mappedScheme

        guard let url = URL(string: "\(scheme)://") else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
