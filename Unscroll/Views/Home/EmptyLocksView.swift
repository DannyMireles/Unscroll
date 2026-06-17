import SwiftUI

struct EmptyLocksView: View {
    var action: (() -> Void)? = nil
    var isSpotlight = false

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Start here")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentDeep)
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
                    .foregroundStyle(AppTheme.accentDeep)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppTheme.accent)
                    .offset(x: 20, y: 18)
            }

            VStack(spacing: 7) {
                Text("Add your first app lock")
                    .font(.headline.weight(.semibold))
                Text("Choose an app. Set a limit. Pick a pause.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                FirstLockGuideRow(number: 1, title: "Choose an app", text: "Use Apple's Screen Time picker.")
                FirstLockGuideRow(number: 2, title: "Set the limit", text: "Decide when Unscroll steps in.")
                FirstLockGuideRow(number: 3, title: "Pick the pause", text: "Math, memory, breathing, or reflection.")
            }

            if let action {
                Button(action: action) {
                    Label("Add your first app", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
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
                .scaleEffect(isSpotlight && isPulsing ? 1.025 : 1.0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(padding: 18)
        .scaleEffect(isSpotlight && isPulsing ? 1.012 : 1.0)
        .shadow(color: isSpotlight ? AppTheme.accent.opacity(0.24) : .clear, radius: 22, x: 0, y: 12)
        .overlay {
            if isSpotlight {
                MovingDottedBorder(cornerRadius: AppTheme.cornerLarge)
            } else {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.36), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isSpotlight)
        .onAppear {
            updatePulse()
        }
        .onChange(of: isSpotlight) { _ in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard isSpotlight else {
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
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = -CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)) * 10

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
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppTheme.accent, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
