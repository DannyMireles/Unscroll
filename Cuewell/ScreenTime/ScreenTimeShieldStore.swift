import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimeShieldStore {
    private static let store = ManagedSettingsStore()

    static func shieldApplications(for locks: [AppLock]) {
        let state = RuntimeStateStore.load()
        let shieldedLocks = locks
            .filter { lock in
                !lock.isPaused &&
                state.exceededLockIDs.contains(lock.id) &&
                !state.hasActiveUnlock(for: lock.id)
            }

        let shieldedApplications = shieldedLocks.reduce(into: Set<ApplicationToken>()) { result, lock in
            result.formUnion(lock.selection.applicationTokens)
        }

        let shieldedCategories = shieldedLocks.reduce(into: Set<ActivityCategoryToken>()) { result, lock in
            result.formUnion(lock.selection.categoryTokens)
        }

        let shieldedWebDomains = shieldedLocks.reduce(into: Set<WebDomainToken>()) { result, lock in
            result.formUnion(lock.selection.webDomainTokens)
        }

        store.shield.applications = shieldedApplications.isEmpty ? nil : shieldedApplications
        store.shield.applicationCategories = shieldedCategories.isEmpty ? nil : .specific(shieldedCategories)
        store.shield.webDomains = shieldedWebDomains.isEmpty ? nil : shieldedWebDomains
    }

    static func clearAllShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
