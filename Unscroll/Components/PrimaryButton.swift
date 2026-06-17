import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isDisabled {
                            Color.secondary.opacity(0.18)
                        } else {
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                )
                .foregroundStyle(isDisabled ? Color.secondary : .white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                .shadow(color: isDisabled ? .clear : AppTheme.accent.opacity(0.28), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
