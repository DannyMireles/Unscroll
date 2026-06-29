import SwiftUI

struct EmptyLocksView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var action: (() -> Void)? = nil
    var isSpotlight = false

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Start here")
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(AppTheme.accentOnChrome)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: Capsule())
                Spacer()
            }

            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 64, height: 64)

                Image(systemName: "lock.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(AppTheme.accentOnChrome)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppTheme.accent)
                    .offset(x: 20, y: 18)
            }

            VStack(spacing: 7) {
                Text("Add your first app lock")
                    .font(AppTheme.Typography.headline)
                Text("Choose an app. Set a limit. Pick a pause.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                FirstLockGuideRow(number: 1, title: "Choose an app", text: "Use Apple's Screen Time picker.")
                FirstLockGuideRow(number: 2, title: "Set the limit", text: "Decide when Cuewell steps in.")
                FirstLockGuideRow(number: 3, title: "Pick the pause", text: "Read, get mindful, go outside, or train your memory.")
            }

            if let action {
                Button(action: action) {
                    Label("Add your first app", systemImage: "plus")
                        .font(AppTheme.Typography.subheadlineMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .scaleEffect(!reduceMotion && isSpotlight && isPulsing ? 1.025 : 1.0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(padding: 18)
        .scaleEffect(!reduceMotion && isSpotlight && isPulsing ? 1.012 : 1.0)
        .shadow(color: isSpotlight ? AppTheme.accent.opacity(0.24) : .clear, radius: 22, x: 0, y: 12)
        .overlay {
            if isSpotlight {
                MovingDottedBorder(cornerRadius: AppTheme.cornerLarge)
            } else {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.36), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            }
        }
        .animation(AppTheme.Motion.selection, value: isSpotlight)
        .onAppear {
            updatePulse()
        }
        .onChange(of: isSpotlight) { _ in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard isSpotlight, !reduceMotion else {
            withAnimation(.easeOut(duration: 0.18)) {
                isPulsing = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

private struct MovingDottedBorder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : nil, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : -CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)) * 10

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AppTheme.accent.opacity(0.78),
                    style: StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        dash: [0.1, 9],
                        dashPhase: phase
                    )
                )
        }
    }
}

private struct FirstLockGuideRow: View {
    let number: Int
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppTheme.accent, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(.primary)
                Text(text)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.chromeStroke, lineWidth: 1)
        }
    }
}
