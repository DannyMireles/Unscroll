import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.33, green: 0.55, blue: 0.52)
    static let accentDeep = Color(red: 0.22, green: 0.39, blue: 0.38)
    static let surface = Color.white.opacity(0.62)
    static let surfaceDark = Color.white.opacity(0.10)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let softShadow = Color.black.opacity(0.08)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.08, green: 0.10, blue: 0.11), Color(red: 0.12, green: 0.15, blue: 0.14)]
                : [Color(red: 0.95, green: 0.97, blue: 0.96), Color(red: 0.88, green: 0.93, blue: 0.91)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45), lineWidth: 1)
            }
            .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 10)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
