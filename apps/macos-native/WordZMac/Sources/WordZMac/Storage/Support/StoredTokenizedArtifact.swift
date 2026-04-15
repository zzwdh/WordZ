import Foundation

struct StoredTokenizedArtifact: Equatable, Sendable {
    let textDigest: String
    let sentences: [TokenizedSentence]
    let tokenCount: Int
    let frequencyMap: [String: Int]

    init(textDigest: String, sentences: [TokenizedSentence]) {
        self.textDigest = textDigest
        self.sentences = sentences
        self.tokenCount = sentences.reduce(0) { $0 + $1.tokens.count }
        self.frequencyMap = sentences
            .flatMap(\.tokens)
            .reduce(into: [:]) { partialResult, token in
                partialResult[token.normalized, default: 0] += 1
            }
    }

    init(textDigest: String, document: ParsedDocument) {
        self.init(
            textDigest: textDigest,
            sentences: document.sentences.map { sentence in
                TokenizedSentence(
                    sentenceId: sentence.sentenceId,
                    text: sentence.text,
                    tokens: sentence.tokens.map { token in
                        TokenizedToken(
                            original: token.original,
                            normalized: token.normalized,
                            sentenceId: token.sentenceId,
                            tokenIndex: token.tokenIndex,
                            annotations: token.annotations
                        )
                    }
                )
            }
        )
    }

    var sentenceCount: Int { sentences.count }

    var tokenizeResult: TokenizeResult {
        TokenizeResult(sentences: sentences)
    }
}
