import SwiftUI

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.accentDeep.opacity(0.7))
            .textCase(.uppercase)
            .tracking(1.4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
