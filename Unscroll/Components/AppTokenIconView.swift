import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

struct AppTokenIconView: View {
    let lock: AppLock

    var body: some View {
        SelectionTokenIcon(
            applicationTokens: lock.selection.applicationTokens,
            categoryTokens: lock.selection.categoryTokens,
            webDomainCount: lock.selectedWebDomainCount,
            selectedItemCount: lock.selectedItemCount
        )
    }
}

struct SelectionTokenIcon: View {
    let applicationTokens: Set<ApplicationToken>
    let categoryTokens: Set<ActivityCategoryToken>
    let webDomainCount: Int
    let selectedItemCount: Int

    init(selection: FamilyActivitySelection) {
        self.applicationTokens = selection.applicationTokens
        self.categoryTokens = selection.categoryTokens
        self.webDomainCount = selection.webDomainTokens.count
        self.selectedItemCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    init(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainCount: Int,
        selectedItemCount: Int
    ) {
        self.applicationTokens = applicationTokens
        self.categoryTokens = categoryTokens
        self.webDomainCount = webDomainCount
        self.selectedItemCount = selectedItemCount
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accentSoft)
                .frame(width: 48, height: 48)

            if let appToken = applicationTokens.first {
                Label(appToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if let categoryToken = categoryTokens.first {
                Label(categoryToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if webDomainCount > 0 {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentDeep)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentDeep)
            }

            if selectedItemCount > 1 {
                Text("\(selectedItemCount)")
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

struct AppTokenTitleView: View {
    let lock: AppLock
    var fallbackName: String?

    var body: some View {
        SelectionTokenTitleView(
            applicationTokens: lock.selection.applicationTokens,
            categoryTokens: lock.selection.categoryTokens,
            webDomainCount: lock.selectedWebDomainCount,
            selectedItemCount: lock.selectedItemCount,
            fallbackName: fallbackName ?? lock.appDisplayName
        )
    }
}

struct SelectionTokenTitleView: View {
    let applicationTokens: Set<ApplicationToken>
    let categoryTokens: Set<ActivityCategoryToken>
    let webDomainCount: Int
    let selectedItemCount: Int
    let fallbackName: String

    var body: some View {
        HStack(spacing: 4) {
            if let appToken = applicationTokens.first {
                Label(appToken)
                    .labelStyle(.titleOnly)
            } else if let categoryToken = categoryTokens.first {
                Label(categoryToken)
                    .labelStyle(.titleOnly)
            } else {
                Text(fallbackName)
            }

            if selectedItemCount > 1 {
                Text("+ \(selectedItemCount - 1)")
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}
