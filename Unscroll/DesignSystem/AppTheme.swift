import SwiftUI

enum AppTheme {
    // MARK: - Color

    /// Primary brand green — calm, focused, used for actions and accents.
    static let accent = Color(red: 0.18, green: 0.46, blue: 0.40)
    /// A deeper green for text/icons that need contrast on light surfaces.
    static let accentDeep = Color(red: 0.11, green: 0.32, blue: 0.28)
    /// A soft tint of the accent for fills and chips.
    static let accentSoft = Color(red: 0.18, green: 0.46, blue: 0.40).opacity(0.12)

    static let surface = Color.white.opacity(0.62)
    static let surfaceDark = Color.white.opacity(0.10)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let softShadow = Color.black.opacity(0.06)

    // MARK: - Shape

    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 16
    static let cornerSmall: CGFloat = 12

    // MARK: - Brand voice

    static let tagline = "Train your mind. Earn your scroll."
    static let subtagline = "Keep the apps you love — just grow a little first."
}

/// App-wide appearance preference, persisted via `@AppStorage("themePreference")`.
enum ThemePreference: String {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.06, green: 0.08, blue: 0.08), Color(red: 0.09, green: 0.13, blue: 0.12)]
                    : [Color(red: 0.97, green: 0.98, blue: 0.97), Color(red: 0.90, green: 0.94, blue: 0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            // A soft glow anchored top-trailing adds depth without clutter.
            RadialGradient(
                colors: [AppTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

/// The primary content surface — a soft, rounded card with a subtle material fill.
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55), lineWidth: 1)
            }
            .shadow(color: AppTheme.softShadow, radius: 18, x: 0, y: 12)
    }
}

extension View {
    func glassCard(padding: CGFloat = 18) -> some View {
        modifier(GlassCard(padding: padding))
    }
}

/// The brand logo on a light tile so the dark artwork stays legible in both light
/// and dark mode (otherwise it disappears against the dark background).
struct BrandLogoView: View {
    var size: CGFloat = 84

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 8)
    }
}

// MARK: - Confetti

/// A lightweight, self-contained confetti burst. Drop it into a ZStack; it animates
/// once on appear. Use a changing `.id(...)` to replay it.
struct ConfettiView: View {
    var pieceCount: Int = 64

    @State private var isAnimating = false

    private let colors: [Color] = [
        AppTheme.accent,
        AppTheme.accentDeep,
        Color(red: 0.97, green: 0.76, blue: 0.29),
        Color(red: 0.93, green: 0.46, blue: 0.43),
        Color(red: 0.40, green: 0.66, blue: 0.86)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { index in
                    piece(index: index, size: geo.size)
                }
            }
            .onAppear { isAnimating = true }
        }
        .allowsHitTesting(false)
    }

    private func piece(index: Int, size: CGSize) -> some View {
        var rng = SeededGenerator(seed: UInt64(index + 1))
        let startX = Double.random(in: 0...max(size.width, 1), using: &rng)
        let endX = startX + Double.random(in: -70...70, using: &rng)
        let width = Double.random(in: 6...11, using: &rng)
        let color = colors[index % colors.count]
        let rotation = Double.random(in: 0...360, using: &rng)
        let duration = Double.random(in: 1.1...2.1, using: &rng)
        let delay = Double.random(in: 0...0.3, using: &rng)
        let fallTo = Double(size.height) + 60

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: width, height: width * 0.62)
            .rotationEffect(.degrees(isAnimating ? rotation + 220 : rotation))
            .position(x: isAnimating ? endX : startX, y: isAnimating ? fallTo : -50)
            .opacity(isAnimating ? 0 : 1)
            .animation(.easeIn(duration: duration).delay(delay), value: isAnimating)
    }
}

/// Deterministic RNG so each confetti piece keeps stable parameters across redraws.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 0x1234_5678
        if state == 0 { state = 0xDEAD_BEEF }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
