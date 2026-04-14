import Foundation

struct MathProblem: Equatable {
    let prompt: String
    let answer: Int
}

enum MathChallengeEngine {
    static func generate() -> MathProblem {
        let operation = weightedOperation()

        switch operation {
        case "+":
            let left = Int.random(in: 18...96)
            let right = Int.random(in: 17...89)
            return MathProblem(prompt: "\(left) + \(right)", answer: left + right)
        case "-":
            let left = Int.random(in: 75...180)
            let right = Int.random(in: 18...74)
            return MathProblem(prompt: "\(left) - \(right)", answer: left - right)
        case "x":
            let left = Int.random(in: 6...14)
            let right = Int.random(in: 7...15)
            return MathProblem(prompt: "\(left) x \(right)", answer: left * right)
        default:
            let divisor = Int.random(in: 3...12)
            let quotient = Int.random(in: 6...16)
            let dividend = divisor * quotient
            return MathProblem(prompt: "\(dividend) / \(divisor)", answer: quotient)
        }
    }

    static func validate(_ text: String, problem: MathProblem) -> Bool {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) == problem.answer
    }

    private static func weightedOperation() -> String {
        let roll = Int.random(in: 1...100)
        switch roll {
        case 1...35: return "+"
        case 36...63: return "-"
        case 64...90: return "x"
        default: return "/"
        }
    }
}
