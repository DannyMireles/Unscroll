import Foundation

struct BreathingStep: Identifiable, Equatable {
    enum Phase: String {
        case inhale = "Inhale"
        case exhale = "Exhale"
    }

    let id = UUID()
    let phase: Phase
    let breathNumber: Int
    let duration: TimeInterval
}

enum BreathingEngine {
    static let steps: [BreathingStep] = (1...3).flatMap { breath in
        [
            BreathingStep(phase: .inhale, breathNumber: breath, duration: 3.6),
            BreathingStep(phase: .exhale, breathNumber: breath, duration: 4.4)
        ]
    }
}
