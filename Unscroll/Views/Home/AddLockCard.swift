import SwiftUI

struct AddLockCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.accentDeep)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create an app lock")
                        .font(.headline.weight(.medium))
                    Text("Choose apps or categories, a daily limit, and a calm unlock.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}
