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
    static let glassHighlight = Color.white.opacity(0.34)
    static let glassLowlight = Color.black.opacity(0.05)
    static let modalScrim = Color.black.opacity(0.18)

    // MARK: - Shape

    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 16
    static let cornerSmall: CGFloat = 12

    // MARK: - Brand voice

    static let tagline = "Train your mind. Earn your scroll."
    static let subtagline = "Keep the apps. Add one clean pause."

    // MARK: - Motion

    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.22)
        static let page = Animation.easeInOut(duration: 0.34)
        static let reveal = Animation.easeOut(duration: 0.46)
        static let emphasis = Animation.easeOut(duration: 0.52)
        static let popup = Animation.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.08)
        static let selection = Animation.spring(response: 0.34, dampingFraction: 0.72, blendDuration: 0.06)
        static let backdrop = Animation.easeInOut(duration: 0.30)

        static let emphasisDelay: UInt64 = 320_000_000

        static func staggerDelay(_ index: Int, step: Double = 0.055, cap: Double = 0.22) -> Double {
            min(Double(max(index, 0)) * step, cap)
        }
    }

    // MARK: - Typography

    enum Typography {
        static let display = Font.system(.largeTitle, design: .rounded).weight(.semibold)
        static let title = Font.system(.title, design: .rounded).weight(.semibold)
        static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let headlineMedium = Font.system(.headline, design: .rounded).weight(.medium)
        static let body = Font.system(.body, design: .rounded)
        static let bodyMedium = Font.system(.body, design: .rounded).weight(.medium)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let subheadlineMedium = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let caption = Font.system(.caption, design: .rounded)
        static let captionMedium = Font.system(.caption, design: .rounded).weight(.medium)
        static let captionSemibold = Font.system(.caption, design: .rounded).weight(.semibold)
        static let footnoteMedium = Font.system(.footnote, design: .rounded).weight(.medium)
        static let footnoteSemibold = Font.system(.footnote, design: .rounded).weight(.semibold)
    }
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
                    ? [
                        Color(red: 0.05, green: 0.07, blue: 0.08),
                        Color(red: 0.08, green: 0.12, blue: 0.11),
                        Color(red: 0.07, green: 0.09, blue: 0.12)
                    ]
                    : [
                        Color(red: 0.98, green: 0.99, blue: 0.98),
                        Color(red: 0.91, green: 0.95, blue: 0.93),
                        Color(red: 0.92, green: 0.95, blue: 0.98)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: colorScheme == .dark
                    ? [AppTheme.accent.opacity(0.10), Color.clear, Color.white.opacity(0.03)]
                    : [AppTheme.accent.opacity(0.09), Color.clear, Color.white.opacity(0.34)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
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
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.26))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.70),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.24),
                                AppTheme.glassLowlight.opacity(colorScheme == .dark ? 0.18 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: 22, x: 0, y: 14)
    }
}

extension View {
    func glassCard(padding: CGFloat = 18) -> some View {
        modifier(GlassCard(padding: padding))
    }

    func flowAppear(delay: Double = 0) -> some View {
        modifier(FlowAppear(delay: delay))
    }

    func flowItem(_ index: Int, step: Double = 0.055) -> some View {
        flowAppear(delay: AppTheme.Motion.staggerDelay(index, step: step))
    }

    @ViewBuilder
    func unscrollTypography() -> some View {
        if #available(iOS 16.1, *) {
            self.fontDesign(.rounded)
        } else {
            self.font(AppTheme.Typography.body)
        }
    }

    @ViewBuilder
    func flowSheetPresentation(dragIndicator: Visibility = .visible) -> some View {
        let base = self.presentationDragIndicator(dragIndicator)
        if #available(iOS 16.4, *) {
            base
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(AppTheme.cornerLarge)
        } else {
            base
        }
    }

    func flowNavigationChrome() -> some View {
        modifier(FlowNavigationChrome())
    }

    func glassBottomBarChrome(horizontalPadding: CGFloat = 20, topPadding: CGFloat = 12, bottomPadding: CGFloat = 12) -> some View {
        modifier(GlassBottomBarChrome(horizontalPadding: horizontalPadding, topPadding: topPadding, bottomPadding: bottomPadding))
    }
}

extension AnyTransition {
    static var flowPopup: AnyTransition {
        .opacity
            .combined(with: .scale(scale: 0.96, anchor: .center))
            .combined(with: .offset(y: 10))
    }
}

struct FlowAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: reduceMotion ? 0 : (isVisible ? 0 : 5))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 8))
            .animation((reduceMotion ? AppTheme.Motion.quick : AppTheme.Motion.reveal).delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

struct FlowNavigationChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
    }
}

struct GlassBottomBarChrome: ViewModifier {
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat = 12
    var bottomPadding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .background {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.36))
                    .frame(height: 1)
            }
    }
}

struct FlowHeadlineText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let lead: String
    let emphasis: String
    var isActive = true
    var font: Font = AppTheme.Typography.title
    var compactFont: Font = AppTheme.Typography.title2
    var isCompact = false
    var alignment: TextAlignment = .center

    @State private var showEmphasis = false

    var body: some View {
        VStack(spacing: isCompact ? 3 : 5) {
            Text(lead)
                .font(isCompact ? compactFont : font)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)

            Text(emphasis)
                .font(isCompact ? compactFont : font)
                .foregroundStyle(AppTheme.accentDeep)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showEmphasis ? 1 : 0)
                .blur(radius: reduceMotion ? 0 : (showEmphasis ? 0 : 4))
                .offset(y: reduceMotion ? 0 : (showEmphasis ? 0 : 6))
        }
        .task(id: isActive) {
            guard isActive else {
                showEmphasis = false
                return
            }

            showEmphasis = false
            try? await Task.sleep(nanoseconds: reduceMotion ? 0 : AppTheme.Motion.emphasisDelay)
            guard !Task.isCancelled else { return }

            withAnimation(reduceMotion ? AppTheme.Motion.quick : AppTheme.Motion.emphasis) {
                showEmphasis = true
            }
        }
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
