import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var lockStore: LockStore
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @EnvironmentObject private var unlockCoordinator: UnlockCoordinator

    @AppStorage("themePreference") private var themePreference = ThemePreference.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var isAddingLock = false
    @State private var editingLock: AppLock?
    @State private var showScreenTimeRequiredAlert = false
    @State private var unavailableAppName: String?
    @State private var readyLock: AppLock?
    @State private var readyIsNewLock = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                hero
                TodayProgressCard(stats: unlockCoordinator.stats)
                locksSection

                if let message = lockStore.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topTrailing) {
            themeToggle
                .padding(.trailing, 18)
                .padding(.top, 6)
        }
        .sheet(isPresented: $isAddingLock) {
            AddLockView(onCreated: { lock in
                readyIsNewLock = true
                readyLock = lock
            })
        }
        .sheet(item: $editingLock) { lock in
            EditLockView(lock: lock)
        }
        .overlay {
            if let lock = readyLock {
                LockReadyPopup(
                    lock: lock,
                    message: readyIsNewLock
                        ? "Locked and ready. Tap it any time to open the app — and once you pass your daily limit, you'll earn time back right here."
                        : "Couldn't open it just now. Open it from your Home Screen, or add the app's name in Edit so the lock can launch it.",
                    buttonTitle: readyIsNewLock ? "Got it" : "OK",
                    onDismiss: { readyLock = nil }
                )
                .zIndex(20)
            }
        }
        .alert("Screen Time Access Needed", isPresented: $showScreenTimeRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Screen Time access is required before creating locks.")
        }
        .alert(
            "Couldn't open \(unavailableAppName ?? "the app")",
            isPresented: Binding(
                get: { unavailableAppName != nil },
                set: { if !$0 { unavailableAppName = nil } }
            )
        ) {
            Button("OK", role: .cancel) { unavailableAppName = nil }
        } message: {
            Text("Open it from your Home Screen for now. We'll detect it automatically once its limit screen has appeared.")
        }
    }

    private var themeToggle: some View {
        Button {
            let goingDark = colorScheme != .dark
            withAnimation(.easeInOut(duration: 0.25)) {
                themePreference = (goingDark ? ThemePreference.dark : .light).rawValue
            }
            Haptics.softTap()
        } label: {
            Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.stars.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentDeep)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: AppTheme.softShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode")
    }

    private var hero: some View {
        VStack(spacing: 14) {
            BrandLogoView(size: 78)

            VStack(spacing: 6) {
                Text("Unscroll")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                Text(AppTheme.tagline)
                    .font(.subheadline.weight(.medium))
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
                SectionTitle(title: "Your Locks")
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
                EmptyLocksView(action: startAddLock)
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
            ForEach(lockStore.locks) { lock in
                LockCard(
                    lock: lock,
                    onEdit: { editingLock = lock },
                    onPause: { Task { await lockStore.togglePause(lock) } },
                    onDelete: { Task { await lockStore.delete(lock) } },
                    onOpenApp: { openOrUnlock(lock) },
                    onCapturedAppName: { name in applyCapturedAppName(name, for: lock) }
                )
            }
        }
    }

    private func startAddLock() {
        Haptics.softTap()
        if permissionManager.isAuthorized {
            isAddingLock = true
        } else {
            showScreenTimeRequiredAlert = true
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
            AppLaunchHelper.openTargetApp(for: lock) {
                handleOpenUnavailable(for: lock)
            }
        }
    }

    /// When an app can't open yet (its identity hasn't been captured), show the "ready"
    /// popup instead of asking the user to type anything. Rendering that popup runs the
    /// usage report, which captures the identity so the next Open works.
    private func handleOpenUnavailable(for lock: AppLock) {
        if canRepairLink(for: lock) {
            readyIsNewLock = false
            readyLock = lock
        } else {
            unavailableAppName = displayNameForAlert(lock)
        }
    }

    private func canRepairLink(for lock: AppLock) -> Bool {
        lock.selection.applicationTokens.count == 1
            && lock.selection.categoryTokens.isEmpty
            && lock.selection.webDomainTokens.isEmpty
    }

    private func displayNameForAlert(_ lock: AppLock) -> String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "the app" : lock.appDisplayName
    }

    private func applyCapturedAppName(_ name: String, for lock: AppLock) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        Task {
            var updated = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
            let resolvedScheme = LockStore.launchSchemes(forName: trimmed).first
                ?? LockStore.normalizeScheme(updated.launchURLScheme)

            guard updated.appDisplayName != trimmed || updated.launchURLScheme != resolvedScheme else {
                return
            }

            updated.appDisplayName = trimmed
            updated.launchURLScheme = resolvedScheme
            NSLog("🔗 Unscroll: self-healed app label '%@' scheme=%@", trimmed, resolvedScheme ?? "")
            await lockStore.update(updated)
        }
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
        .animation(.easeInOut(duration: 0.4), value: isActive)
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
                .scaleEffect(pulse ? 1.08 : 0.94)

            Image(systemName: isActive ? "flame.fill" : "snowflake")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(pulse ? 1.07 : 0.95)
                .shadow(color: glow.opacity(pulse ? 0.95 : 0.35), radius: pulse ? 13 : 5)
        }
        .onAppear { startPulsing() }
        .onChange(of: isActive) { _ in startPulsing() }
    }

    private func startPulsing() {
        pulse = false
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
