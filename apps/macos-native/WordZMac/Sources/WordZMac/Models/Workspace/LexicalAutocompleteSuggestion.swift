import Foundation

struct LexicalAutocompleteSuggestion: Equatable, Sendable {
    let term: String
    let count: Int
    let rank: Int?
}
