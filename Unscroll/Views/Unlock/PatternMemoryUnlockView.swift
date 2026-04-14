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
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 12)

                UnlockHeader(
                    lock: lock,
                    title: "Copy one simple pattern.",
                    subtitle: "Watch it slowly, then tap those same tiles in order."
                )

                VStack(spacing: 18) {
                    Text(message)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)

                    grid

                    Button("Replay") {
                        Task { await playSequence() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accentDeep)
                    .disabled(isPlaying)
                }
                .glassCard()
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
        .padding(.vertical, 24)
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
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: highlightedTile)
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
            message = "Not quite. Same pattern, one more try."
            userInput = []
            Task { await playSequence() }
            return
        }

        if userInput.count == sequence.count {
            onComplete()
        } else {
            message = "\(sequence.count - userInput.count) left"
        }
    }

    private func playSequence() async {
        isPlaying = true
        userInput = []
        message = "Watch one clear pattern."
        try? await Task.sleep(nanoseconds: 800_000_000)

        for tile in sequence {
            highlightedTile = tile
            Haptics.softTap()
            try? await Task.sleep(nanoseconds: 900_000_000)
            highlightedTile = nil
            try? await Task.sleep(nanoseconds: 350_000_000)
        }

        message = "Your turn."
        isPlaying = false
    }
}
