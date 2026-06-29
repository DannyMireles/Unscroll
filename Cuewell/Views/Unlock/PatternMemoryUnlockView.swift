import SwiftUI

struct PatternMemoryUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var sequence = PatternMemoryEngine.generateSequence()
    @State private var userInput: [Int] = []
    @State private var highlightedTile: Int?
    @State private var isPlaying = true
    @State private var message = "Watch one clear pattern."

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Copy one simple pattern.",
            subtitle: "Watch it slowly, then tap those same tiles in order."
        ) {
            VStack(spacing: 18) {
                Text(message)
                    .font(AppTheme.Typography.headlineMedium)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)

                grid

                Button("Replay") {
                    Task { await playSequence() }
                }
                .font(AppTheme.Typography.subheadlineMedium)
                .foregroundStyle(AppTheme.accentOnChrome)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(AppTheme.chromeStroke, lineWidth: 1) }
                .disabled(isPlaying)
                .opacity(isPlaying ? 0.58 : 1)
            }
        }
        .animation(AppTheme.Motion.quick, value: message)
        .task {
            await playSequence()
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                Button {
                    tap(index)
                } label: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tileColor(for: index))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        }
                        .scaleEffect(highlightedTile == index ? 1.04 : 1.0)
                        .animation(AppTheme.Motion.selection, value: highlightedTile)
                }
                .buttonStyle(.plain)
                .disabled(isPlaying)
            }
        }
    }

    private func tileColor(for index: Int) -> Color {
        if highlightedTile == index {
            return AppTheme.accent
        }
        if userInput.contains(index) {
            return AppTheme.accent.opacity(0.18)
        }
        return Color.secondary.opacity(0.12)
    }

    private func tap(_ index: Int) {
        guard !isPlaying else { return }
        Haptics.softTap()
        userInput.append(index)

        guard PatternMemoryEngine.isCorrect(prefix: userInput, sequence: sequence) else {
            Haptics.retry()
            userInput = []
            // Re-show the correct pattern so they can see the right order before retrying.
            Task { await playSequence(intro: "Not quite. Watch the correct pattern.") }
            return
        }

        if userInput.count == sequence.count {
            onComplete()
        } else {
            message = "\(sequence.count - userInput.count) left"
        }
    }

    private func playSequence(intro: String = "Watch the pattern.") async {
        isPlaying = true
        userInput = []
        message = intro
        try? await Task.sleep(nanoseconds: 350_000_000)

        for tile in sequence {
            highlightedTile = tile
            Haptics.softTap()
            try? await Task.sleep(nanoseconds: 480_000_000)
            highlightedTile = nil
            try? await Task.sleep(nanoseconds: 170_000_000)
        }

        message = "Your turn."
        isPlaying = false
    }
}
