import Foundation

struct MathProblem: Equatable {
    let prompt: String
    let answer: Int
}

/// Generates short arithmetic-and-reasoning prompts. The goal is to keep the mind
/// engaged (not just tap a button), while always resolving to a single integer
/// answer that is quick to type. Variety is intentional: plain operations build
/// fluency, multi-term and percentage prompts add light load, and sequences ask
/// the user to spot a numeric pattern.
enum MathChallengeEngine {
    private enum Kind: CaseIterable {
        case addition
        case subtraction
        case multiplication
        case division
        case threeTerm
        case percentage
        case sequence
    }

    static func generate() -> MathProblem {
        switch Kind.allCases.randomElement() ?? .addition {
        case .addition:
            let a = Int.random(in: 24...98)
            let b = Int.random(in: 18...89)
            return MathProblem(prompt: "\(a) + \(b)", answer: a + b)

        case .subtraction:
            let a = Int.random(in: 80...180)
            let b = Int.random(in: 19...78)
            return MathProblem(prompt: "\(a) − \(b)", answer: a - b)

        case .multiplication:
            let a = Int.random(in: 6...15)
            let b = Int.random(in: 7...15)
            return MathProblem(prompt: "\(a) × \(b)", answer: a * b)

        case .division:
            let divisor = Int.random(in: 3...12)
            let quotient = Int.random(in: 6...16)
            return MathProblem(prompt: "\(divisor * quotient) ÷ \(divisor)", answer: quotient)

        case .threeTerm:
            let a = Int.random(in: 30...80)
            let b = Int.random(in: 12...44)
            let c = Int.random(in: 5...28)
            return MathProblem(prompt: "\(a) + \(b) − \(c)", answer: a + b - c)

        case .percentage:
            let percent = [10, 20, 25, 50].randomElement() ?? 25
            // Base is a multiple of 20, which keeps every listed percentage an integer.
            let base = Int.random(in: 2...9) * 20
            return MathProblem(prompt: "\(percent)% of \(base)", answer: base * percent / 100)

        case .sequence:
            return sequenceProblem()
        }
    }

    static func validate(_ text: String, problem: MathProblem) -> Bool {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) == problem.answer
    }

    /// Builds either an arithmetic (constant difference) or geometric (constant
    /// ratio) sequence and asks for the next term.
    private static func sequenceProblem() -> MathProblem {
        if Bool.random() {
            let start = Int.random(in: 2...12)
            let step = Int.random(in: 2...9)
            let terms = (0...3).map { start + $0 * step }
            let next = start + 4 * step
            return MathProblem(prompt: sequencePrompt(terms), answer: next)
        } else {
            let start = Int.random(in: 1...4)
            let ratio = Int.random(in: 2...3)
            let terms = (0...3).map { start * pow(ratio, $0) }
            let next = start * pow(ratio, 4)
            return MathProblem(prompt: sequencePrompt(terms), answer: next)
        }
    }

    private static func sequencePrompt(_ terms: [Int]) -> String {
        (terms.map(String.init) + ["?"]).joined(separator: ", ")
    }

    private static func pow(_ base: Int, _ exponent: Int) -> Int {
        guard exponent > 0 else { return 1 }
        return (1...exponent).reduce(1) { result, _ in result * base }
    }
}
