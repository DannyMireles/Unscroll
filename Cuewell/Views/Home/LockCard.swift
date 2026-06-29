import DeviceActivity
import SwiftUI

struct LockCard: View {
    let lock: AppLock
    let onInfo: () -> Void
    let onEdit: () -> Void
    let onPause: () -> Void
    let onLockNow: () -> Void
    let onDelete: () -> Void
    let onOpenApp: () -> Void
    let onCapturedAppName: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.softTap()
                onOpenApp()
            } label: {
                HStack(spacing: 14) {
                    AppTokenIconView(lock: lock)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            AppTokenTitleView(lock: lock)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.primary)

                            if lock.isPaused {
                                Text("Paused")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.16), in: Capsule())
                            }
                        }

                        Text(metaLine)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lock.canDeepLink ? "Open \(lock.appDisplayName)" : "Open lock")

            Menu {
                Button {
                    Haptics.softTap()
                    onInfo()
                } label: { Label("Usage & Info", systemImage: "info.circle") }
                Button {
                    Haptics.softTap()
                    onEdit()
                } label: { Label("Edit", systemImage: "slider.horizontal.3") }
                Button {
                    Haptics.softTap()
                    onPause()
                } label: {
                    Label(lock.isPaused ? "Resume" : "Pause", systemImage: lock.isPaused ? "play.fill" : "pause.fill")
                }
                if !lock.isPaused {
                    Button {
                        Haptics.success()
                        onLockNow()
                    } label: { Label("Lock now", systemImage: "lock.fill") }
                }
                Button(role: .destructive) {
                    Haptics.softTap()
                    onDelete()
                } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.32), lineWidth: 1)
                    }
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.softTap() })
        }
        .glassCard(padding: 16)
        .overlay(alignment: .topLeading) {
            if lock.selection.applicationTokens.count == 1,
               lock.selection.categoryTokens.isEmpty,
               lock.selection.webDomainTokens.isEmpty,
               let token = lock.selection.applicationTokens.first {
                ZStack(alignment: .topLeading) {
                    ApplicationTokenNameCapture(token: token) { _, name in
                        onCapturedAppName(name)
                    }
                    .id(token.hashValue)
                    .frame(width: 260, height: 44)

                    AppIdentityReportCapture(selection: lock.selection)
                }
            }
        }
    }

    private var metaLine: String {
        let reward = lock.unlockRewardMode == .incrementalByLimit ? "Incremental" : "Rest of day"
        return "\(lock.limitLabel) daily · \(methodLabel) · \(reward)"
    }

    private var methodLabel: String {
        let extra = lock.unlockMethods.count - 1
        return extra > 0
            ? "\(lock.primaryMethod.shortTitle) +\(extra)"
            : lock.primaryMethod.shortTitle
    }
}

// MARK: - Lock info / usage

/// Reachable from a lock's "⋯ → Usage & Info" menu. Shows how much the locked app(s)
/// have actually been used (today and over the last week, read from Screen Time) plus
/// the lock's own settings.
struct LockInfoView: View {
    let lock: AppLock
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        usageSection
                        detailsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Usage & Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.softTap()
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppTokenIconView(lock: lock)
            VStack(alignment: .leading, spacing: 4) {
                AppTokenTitleView(lock: lock)
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(.primary)
                Text(lock.isPaused ? "Paused" : "\(lock.limitLabel) of use per day")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 16)
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Time Used")

            VStack(alignment: .leading, spacing: 12) {
                if #available(iOS 16.0, *), lock.hasSelection {
                    DeviceActivityReport(usageContext, filter: usageFilter)
                        .frame(height: 96)
                } else {
                    Text("Usage tracking needs iOS 16 or later.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Counted while you're actually using the app, not while it sits idle.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("Today's count starts when the lock is created. To block an app you've already used a lot today, open the lock's menu and tap Lock now.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassCard(padding: 16)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "How This Lock Works")

            VStack(spacing: 0) {
                infoRow(title: "Daily limit", value: "\(lock.limitLabel) of use")
                Divider().opacity(0.4)
                infoRow(title: "When you reach it", value: rewardValue)
                Divider().opacity(0.4)
                infoRow(title: "Unlock with", value: methodsValue)
            }
            .glassCard(padding: 16)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(AppTheme.Typography.subheadlineMedium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private var rewardValue: String {
        switch lock.unlockRewardMode {
        case .incrementalByLimit:
            return "Do an activity for \(AppConstants.grantedMinutes(for: lock.dailyLimitMinutes)) more min of use"
        case .unlockedRestOfDay:
            return "Do an activity to open it for the rest of the day"
        }
    }

    private var methodsValue: String {
        lock.unlockMethods.map(\.shortTitle).joined(separator: ", ")
    }

    @available(iOS 16.0, *)
    private var usageContext: DeviceActivityReport.Context {
        DeviceActivityReport.Context("Cuewell Lock Usage")
    }

    @available(iOS 16.0, *)
    private var usageFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        let interval = DateInterval(start: start, end: Date())
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .all,
            applications: lock.selection.applicationTokens,
            categories: lock.selection.categoryTokens,
            webDomains: lock.selection.webDomainTokens
        )
    }
}
