import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var lockStore: LockStore
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @EnvironmentObject private var unlockCoordinator: UnlockCoordinator
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("themePreference") private var themePreference = ThemePreference.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var isAddingLock = false
    @State private var showUpgradeSheet = false
    @State private var editingLock: AppLock?
    @State private var showScreenTimeRequiredAlert = false
    @State private var unavailableLock: AppLock?
    @State private var linkSetupLock: AppLock?
    @State private var didAutoScrollToFirstLockGuide = false
    @State private var showFirstLockSpotlight = false
    @State private var isRequestingNotificationPermission = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage("didActOnFirstLockSpotlight") private var didActOnFirstLockSpotlight = false

    private let firstLockGuideID = "firstLockGuide"

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 26) {
                    hero
                        .blur(radius: showFirstLockSpotlight ? 3 : 0)
                        .opacity(showFirstLockSpotlight ? 0.62 : 1)
                        .flowItem(0)
                    TodayProgressCard(stats: unlockCoordinator.stats)
                        .blur(radius: showFirstLockSpotlight ? 3 : 0)
                        .opacity(showFirstLockSpotlight ? 0.62 : 1)
                        .flowItem(1)
                    locksSection
                        .flowItem(2)

                    if let message = lockStore.lastErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .flowItem(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .onAppear {
                scrollToFirstLockGuideIfNeeded(using: scrollProxy)
            }
            .onChange(of: lockStore.locks.isEmpty) { _ in
                scrollToFirstLockGuideIfNeeded(using: scrollProxy)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if shouldShowNotificationAction {
                    notificationActionButton
                }
                themeToggle
            }
            .padding(.trailing, 18)
            .padding(.top, 6)
        }
        .overlay {
            if let linkSetupLock {
                AppLinkSetupView(
                    lock: linkSetupLock,
                    onLinked: openLinkedApp,
                    onCancel: { dismissLinkSetup() }
                )
                .id(linkSetupLock.id)
                .transition(.flowPopup)
                .zIndex(20)
            }

            if showScreenTimeRequiredAlert {
                GlassNoticeOverlay(
                    title: "Screen Time Access Needed",
                    message: "Screen Time access is required before creating locks."
                ) {
                    withAnimation(AppTheme.Motion.popup) {
                        showScreenTimeRequiredAlert = false
                    }
                }
                .transition(.flowPopup)
                .zIndex(21)
            }

            if let unavailableLock {
                GlassNoticeOverlay(
                    title: unavailableTitle(for: unavailableLock),
                    message: unavailableMessage(for: unavailableLock)
                ) {
                    withAnimation(AppTheme.Motion.popup) {
                        self.unavailableLock = nil
                    }
                }
                .transition(.flowPopup)
                .zIndex(22)
            }
        }
        .animation(AppTheme.Motion.popup, value: linkSetupLock?.id)
        .animation(AppTheme.Motion.popup, value: showScreenTimeRequiredAlert)
        .animation(AppTheme.Motion.popup, value: unavailableLock?.id)
        .task {
            await refreshNotificationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
        .sheet(isPresented: $isAddingLock) {
            AddLockView(onCreated: { _ in
                requestNotificationPermissionAfterSheetDismisses()
            })
            .flowSheetPresentation()
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeSheet()
                .environmentObject(purchaseManager)
                .flowSheetPresentation()
        }
        .sheet(item: $editingLock) { lock in
            EditLockView(lock: lock)
                .flowSheetPresentation()
        }
    }

    private var themeToggle: some View {
        Button {
            let goingDark = colorScheme != .dark
            withAnimation(AppTheme.Motion.quick) {
                themePreference = (goingDark ? ThemePreference.dark : .light).rawValue
            }
            Haptics.softTap()
        } label: {
            Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.stars.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentOnChrome)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(AppTheme.chromeStroke, lineWidth: 1)
                }
                .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode")
    }

    private var shouldShowNotificationAction: Bool {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return false
        case .denied, .notDetermined:
            return true
        @unknown default:
            return true
        }
    }

    private var notificationActionButton: some View {
        Button {
            Haptics.softTap()
            Task { await handleNotificationAction() }
        } label: {
            Image(systemName: notificationAuthorizationStatus == .denied ? "bell.slash.fill" : "bell.badge.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(notificationAuthorizationStatus == .denied ? Color.red : AppTheme.accentOnChrome)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(AppTheme.chromeStroke, lineWidth: 1)
                }
                .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(notificationAuthorizationStatus == .denied ? "Open notification settings" : "Enable notifications")
    }

    private var hero: some View {
        VStack(spacing: 14) {
            BrandLogoView(size: 78)

            VStack(spacing: 6) {
                Text("Cuewell")
                    .font(AppTheme.Typography.title)
                Text(AppTheme.tagline)
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(AppTheme.accentDeep.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var locksSection: some View {
        VStack(spacing: 14) {
            HStack {
                SectionTitle(title: "App Locks")
                Spacer()
                Button(action: startAddLock) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if lockStore.locks.isEmpty {
                EmptyLocksView(action: startAddLock, isSpotlight: showFirstLockSpotlight)
                    .id(firstLockGuideID)
            } else if lockStore.locks.count > 3 {
                // Keep a long list from pushing the page down — scroll within the section.
                ScrollView(.vertical, showsIndicators: true) {
                    lockList
                        .padding(.vertical, 2)
                }
                .frame(height: 320)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                lockList
            }
        }
    }

    private var lockList: some View {
        VStack(spacing: 12) {
            ForEach(Array(lockStore.locks.enumerated()), id: \.element.id) { index, lock in
                LockCard(
                    lock: lock,
                    onEdit: { editingLock = lock },
                    onPause: { handlePauseToggle(for: lock) },
                    onDelete: { Task { await lockStore.delete(lock) } },
                    onOpenApp: { openOrUnlock(lock) },
                    onCapturedAppName: { name in applyCapturedAppName(name, for: lock) }
                )
                .flowItem(index)
            }
        }
    }

    private func startAddLock() {
        Haptics.softTap()
        if permissionManager.isAuthorized {
            didActOnFirstLockSpotlight = true
            withAnimation(AppTheme.Motion.quick) {
                showFirstLockSpotlight = false
            }
            if purchaseManager.canCreateLock(activeLockCount: activeLockCount) {
                isAddingLock = true
            } else {
                showUpgradePrompt()
            }
        } else {
            withAnimation(AppTheme.Motion.popup) {
                showScreenTimeRequiredAlert = true
            }
        }
    }

    private var activeLockCount: Int {
        lockStore.locks.filter { !$0.isPaused }.count
    }

    private func handlePauseToggle(for lock: AppLock) {
        if lock.isPaused && !purchaseManager.canCreateLock(activeLockCount: activeLockCount) {
            showUpgradePrompt()
            return
        }

        Task { await lockStore.togglePause(lock) }
    }

    private func showUpgradePrompt() {
        withAnimation(AppTheme.Motion.popup) {
            showUpgradeSheet = true
        }
    }

    /// Tapping a lock should always get the user to their app. If the lock is currently
    /// over its limit (shielded), open the unlock activity first — otherwise opening the
    /// app would just bounce straight back to the shield. If it isn't locked, go directly.
    private func openOrUnlock(_ lock: AppLock) {
        let state = RuntimeStateStore.load()
        let isLocked = !lock.isPaused
            && state.exceededLockIDs.contains(lock.id)
            && !state.hasActiveUnlock(for: lock.id)

        if isLocked {
            unlockCoordinator.activeLock = lock
        } else {
            let currentLock = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
            guard currentLock.canDeepLink else {
                handleOpenUnavailable(for: currentLock)
                return
            }
            AppLaunchHelper.openTargetApp(for: currentLock) {
                handleOpenUnavailable(for: currentLock)
            }
        }
    }

    /// Tapping "Open" can't launch anything when a lock doesn't resolve to one app. Surface an
    /// honest message; for a category / multi-app lock there's simply no single app to open.
    private func handleOpenUnavailable(for lock: AppLock) {
        withAnimation(AppTheme.Motion.popup) {
            if lock.canDeepLink {
                linkSetupLock = lock
            } else {
                unavailableLock = lock
            }
        }
    }

    private func openLinkedApp(_ lock: AppLock) {
        dismissLinkSetup()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AppLaunchHelper.openTargetApp(for: lock) {
                handleOpenUnavailable(for: lock)
            }
        }
    }

    private func dismissLinkSetup() {
        withAnimation(AppTheme.Motion.popup) {
            linkSetupLock = nil
        }
    }

    private func applyCapturedAppName(_ name: String, for lock: AppLock) {
        guard lock.canDeepLink,
              let token = lock.selection.applicationTokens.first
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        AppIdentityStore.record(token: token, bundleID: nil, displayName: trimmed)
        let resolvedScheme = LockStore.launchSchemes(forName: trimmed).first
            ?? LockStore.normalizeScheme(lock.launchURLScheme)

        Task {
            var updated = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
            guard updated.appDisplayName != trimmed || updated.launchURLScheme != resolvedScheme else { return }
            updated.appDisplayName = trimmed
            updated.launchURLScheme = resolvedScheme
            NSLog("🔗 Cuewell: self-healed app label '%@' scheme=%@", trimmed, resolvedScheme ?? "")
            await lockStore.update(updated)
            await lockStore.resolveAndApplyAppStoreIdentity(lockID: updated.id, token: token, name: trimmed)
        }
    }

    private func scrollToFirstLockGuideIfNeeded(using proxy: ScrollViewProxy) {
        guard lockStore.locks.isEmpty, !didAutoScrollToFirstLockGuide, !didActOnFirstLockSpotlight else { return }
        didAutoScrollToFirstLockGuide = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard lockStore.locks.isEmpty else { return }
            withAnimation(AppTheme.Motion.popup) {
                proxy.scrollTo(firstLockGuideID, anchor: .top)
            }
            withAnimation(AppTheme.Motion.quick) {
                showFirstLockSpotlight = true
            }
        }
    }

    private func requestNotificationPermissionAfterSheetDismisses() {
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await requestNotificationPermissionAfterReadyIfNeeded()
        }
    }

    @MainActor
    private func requestNotificationPermissionAfterReadyIfNeeded() async {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        defer { isRequestingNotificationPermission = false }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationAuthorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .notDetermined else { return }

        try? await Task.sleep(nanoseconds: 300_000_000)
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshNotificationStatus()
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationAuthorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    private func handleNotificationAction() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationAuthorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .notDetermined:
            guard !isRequestingNotificationPermission else { return }
            isRequestingNotificationPermission = true
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            isRequestingNotificationPermission = false
            await refreshNotificationStatus()
        case .denied:
            openAppSettings()
        default:
            await refreshNotificationStatus()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func displayNameForAlert(_ lock: AppLock) -> String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "the app" : lock.appDisplayName
    }

    private func unavailableTitle(for lock: AppLock) -> String {
        lock.canDeepLink ? "Couldn't open \(displayNameForAlert(lock))" : "Apps unlocked"
    }

    private func unavailableMessage(for lock: AppLock) -> String {
        if lock.canDeepLink {
            return "This link needs one quick setup step."
        }
        return "Your apps are unlocked. Open any of them from your Home Screen."
    }

}

private struct TodayProgressCard: View {
    let stats: DailyStats

    var body: some View {
        VStack(spacing: 12) {
            streakBanner
            HStack(spacing: 12) {
                StatTile(value: "\(stats.sessionsToday)", label: "Sessions today", systemImage: "checkmark.seal.fill")
                StatTile(value: "\(stats.minutesToday)", label: "Minutes earned", systemImage: "clock.fill")
            }
        }
    }

    private var isActive: Bool { stats.streak > 0 }

    private var streakBanner: some View {
        HStack(spacing: 16) {
            AnimatedStreakIcon(isActive: isActive)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(stats.streak)")
                        .font(.system(size: 42, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("day\(stats.streak == 1 ? "" : "s")")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("streak")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 8)

            Text(streakMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: isActive
                    ? [AppTheme.accent, AppTheme.accentDeep]
                    : [Color(red: 0.40, green: 0.52, blue: 0.60), Color(red: 0.24, green: 0.34, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
        )
        .shadow(
            color: (isActive ? AppTheme.accent : Color(red: 0.30, green: 0.42, blue: 0.50)).opacity(0.32),
            radius: 16, x: 0, y: 10
        )
        .animation(AppTheme.Motion.reveal, value: isActive)
    }

    private var streakMessage: String {
        switch stats.streak {
        case 0: return "Start your streak today"
        case 1: return "Great start — come back tomorrow"
        case 2...4: return "You're building a habit"
        default: return "You're on a roll!"
        }
    }
}

/// A streak icon that gently breathes and glows: a flickering flame when the streak is
/// alive, or a cool, frosted state inviting the user to start one.
private struct AnimatedStreakIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool

    @State private var pulse = false

    private var glow: Color {
        isActive ? Color(red: 1.0, green: 0.62, blue: 0.18) : Color(red: 0.55, green: 0.82, blue: 0.95)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 60, height: 60)
                .scaleEffect(!reduceMotion && pulse ? 1.08 : 0.94)

            Image(systemName: isActive ? "flame.fill" : "snowflake")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(!reduceMotion && pulse ? 1.07 : 0.95)
                .shadow(color: glow.opacity(!reduceMotion && pulse ? 0.95 : 0.35), radius: !reduceMotion && pulse ? 13 : 5)
        }
        .onAppear { startPulsing() }
        .onChange(of: isActive) { _ in startPulsing() }
    }

    private func startPulsing() {
        pulse = false
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: isActive ? 0.85 : 1.7).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}
