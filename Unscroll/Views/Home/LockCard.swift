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
                                .font(.headline.weight(.semibold))
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(lock.appDisplayName)")

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
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.10), in: Circle())
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.softTap() })
        }
        .glassCard(padding: 16)
        .overlay(alignment: .topLeading) {
            if lock.selection.applicationTokens.count == 1,
               lock.selection.categoryTokens.isEmpty,
               lock.selection.webDomainTokens.isEmpty,
               let token = lock.selection.applicationTokens.first {
                ApplicationTokenNameCapture(token: token) { _, name in
                    onCapturedAppName(name)
                }
                .id(token.hashValue)
            }
        }
    }

    private var metaLine: String {
        let reward = lock.unlockRewardMode == .incrementalByLimit ? "Incremental" : "Rest of day"
        return "\(lock.limitLabel) daily · \(lock.unlockMethod.shortTitle) · \(reward)"
    }
}
