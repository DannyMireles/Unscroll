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
    static let subtagline = "Keep the apps. Add one clean pause."
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

struct BrandAppLockMark: View {
    let lock: AppLock
    var size: CGFloat = 104

    var body: some View {
        HStack(spacing: -size * 0.10) {
            BrandLogoView(size: size)

            AppTokenIconView(lock: lock)
                .scaleEffect(size >= 104 ? 1.18 : 1.02)
                .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 7)
        }
        .frame(width: size * 1.45, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Confetti

enum ConfettiStart {
    case top
    case point(UnitPoint)
}

/// A lightweight, self-contained confetti burst. Drop it into a ZStack; it animates
/// once on appear. Use a changing `.id(...)` to replay it.
struct ConfettiView: View {
    var pieceCount: Int = 64
    var start: ConfettiStart = .top

    @State private var hasBurst = false
    @State private var hasFallen = false

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
            .onAppear { startAnimation() }
        }
        .allowsHitTesting(false)
    }

    private func piece(index: Int, size: CGSize) -> some View {
        var rng = SeededGenerator(seed: UInt64(index + 1))
        let trajectory = trajectory(index: index, size: size, rng: &rng)
        let current = currentPosition(for: trajectory)
        let width = Double.random(in: 6...11, using: &rng)
        let color = colors[index % colors.count]
        let rotation = Double.random(in: 0...360, using: &rng)
        let fallDuration = trajectory.isBurst ? Double.random(in: 2.35...3.35, using: &rng) : Double.random(in: 1.25...2.1, using: &rng)
        let delay = Double.random(in: 0...(trajectory.isBurst ? 0.18 : 0.3), using: &rng)
        let isMoving = trajectory.isBurst ? (hasBurst || hasFallen) : hasFallen

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: width, height: width * 0.62)
            .rotationEffect(.degrees(isMoving ? rotation + 260 : rotation))
            .position(x: current.x, y: current.y)
            .opacity(hasFallen ? 0 : 1)
            .animation(.easeOut(duration: trajectory.isBurst ? 0.46 : 0).delay(delay), value: hasBurst)
            .animation(.easeIn(duration: fallDuration).delay(delay), value: hasFallen)
    }

    private func startAnimation() {
        switch start {
        case .top:
            hasFallen = true
        case .point:
            hasBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                hasFallen = true
            }
        }
    }

    private func currentPosition(for trajectory: ConfettiTrajectory) -> CGPoint {
        guard trajectory.isBurst else {
            return hasFallen ? trajectory.end : trajectory.start
        }

        if hasFallen { return trajectory.end }
        if hasBurst { return trajectory.burst }
        return trajectory.start
    }

    private func trajectory(index: Int, size: CGSize, rng: inout SeededGenerator) -> ConfettiTrajectory {
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        switch start {
        case .top:
            let sourceX = CGFloat(Double.random(in: 0...Double(width), using: &rng))
            let start = CGPoint(x: sourceX, y: -50)
            let end = CGPoint(
                x: sourceX + CGFloat(Double.random(in: -70...70, using: &rng)),
                y: height + 60
            )
            return ConfettiTrajectory(start: start, burst: start, end: end, isBurst: false)
        case .point(let point):
            let jitterX = CGFloat(Double.random(in: -16...16, using: &rng))
            let jitterY = CGFloat(Double.random(in: -8...8, using: &rng))
            let source = CGPoint(
                x: clamped(width * point.x + jitterX, lower: 0, upper: width),
                y: clamped(height * point.y + jitterY, lower: 0, upper: height)
            )
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let sideSpread = CGFloat(Double.random(in: 46...150, using: &rng))
            let upwardLaunch = CGFloat(Double.random(in: 76...165, using: &rng))
            let burst = CGPoint(
                x: clamped(source.x + side * sideSpread, lower: -16, upper: width + 16),
                y: max(-30, source.y - upwardLaunch)
            )
            let end = CGPoint(
                x: clamped(burst.x + CGFloat(Double.random(in: -54...54, using: &rng)), lower: -24, upper: width + 24),
                y: height + 90
            )
            return ConfettiTrajectory(start: source, burst: burst, end: end, isBurst: true)
        }
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private struct ConfettiTrajectory {
        let start: CGPoint
        let burst: CGPoint
        let end: CGPoint
        let isBurst: Bool
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
