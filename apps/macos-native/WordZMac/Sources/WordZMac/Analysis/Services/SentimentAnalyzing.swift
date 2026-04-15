import Foundation

protocol SentimentAnalyzing {
    func analyze(_ request: SentimentRunRequest) throws -> SentimentRunResult
}

