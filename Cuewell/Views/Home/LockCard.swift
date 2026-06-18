import SwiftUI

struct LockCard: View {
    let lock: AppLock
    let onEdit: () -> Void
    let onPause: () -> Void
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
                    onEdit()
                } label: { Label("Edit", systemImage: "slider.horizontal.3") }
                Button {
                    Haptics.softTap()
                    onPause()
                } label: {
                    Label(lock.isPaused ? "Resume" : "Pause", systemImage: lock.isPaused ? "play.fill" : "pause.fill")
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
