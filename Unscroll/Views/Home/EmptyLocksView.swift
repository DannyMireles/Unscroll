import SwiftUI

struct EmptyLocksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.accent)

            Text("No locks yet")
                .font(.headline.weight(.medium))

            Text("Add one app to begin creating a little more space before you scroll.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}
