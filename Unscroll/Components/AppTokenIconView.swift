import FamilyControls
import SwiftUI

struct AppTokenIconView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.accent.opacity(0.14))
                .frame(width: 46, height: 46)

            if let appToken = lock.selection.applicationTokens.first {
                Label(appToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if let categoryToken = lock.selection.categoryTokens.first {
                Label(categoryToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if lock.selectedWebDomainCount > 0 {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentDeep)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentDeep)
            }

            if lock.selectedItemCount > 1 {
                Text("\(lock.selectedItemCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.accentDeep, in: Capsule())
                    .offset(x: 17, y: -17)
            }
        }
        .accessibilityHidden(true)
    }
}
