import SwiftUI

struct EmptyLocksView: View {
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 60, height: 60)
                Image(systemName: "lock.open")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(spacing: 6) {
                Text("No locks yet")
                    .font(.headline.weight(.semibold))
                Text("Add an app you want to use more intentionally. You'll keep access — you'll just train your mind first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let action {
                Button(action: action) {
                    Text("Add your first lock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(padding: 22)
    }
}
