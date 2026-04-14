import Foundation

enum PatternMemoryEngine {
    static let sequenceLength = 3

    static func generateSequence() -> [Int] {
        var uniqueTiles = Array(0...8)
        uniqueTiles.shuffle()
        return Array(uniqueTiles.prefix(sequenceLength))
    }

    static func isCorrect(prefix: [Int], sequence: [Int]) -> Bool {
        guard prefix.count <= sequence.count else { return false }
        return Array(sequence.prefix(prefix.count)) == prefix
    }
}
