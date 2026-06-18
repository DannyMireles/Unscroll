import UIKit
import AudioToolbox

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func retry() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func softTap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func celebrationDing() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // A lighter "tink" style chime than the previous bell-like tone.
        AudioServicesPlaySystemSound(1113)
    }
}
