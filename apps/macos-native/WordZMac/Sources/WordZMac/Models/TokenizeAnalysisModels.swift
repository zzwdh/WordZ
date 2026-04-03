import Foundation

struct TokenizedToken: Identifiable, Hashable, Sendable {
    let original: String
    let normalized: String
    let sentenceId: Int
    let tokenIndex: Int

    var id: String { "\(sentenceId)-\(tokenIndex)" }

    init(original: String, normalized: String, sentenceId: Int, tokenIndex: Int) {
        self.original = original
        self.normalized = normalized
        self.sentenceId = sentenceId
        self.tokenIndex = tokenIndex
    }

    init(json: JSONObject) {
        self.original = JSONFieldReader.string(json, key: "original")
        self.normalized = JSONFieldReader.string(json, key: "normalized")
        self.sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        self.tokenIndex = JSONFieldReader.int(json, key: "tokenIndex")
    }
}

struct TokenizedSentence: Identifiable, Equatable, Sendable {
    let sentenceId: Int
    let text: String
    let tokens: [TokenizedToken]

    var id: String { "\(sentenceId)" }

    init(sentenceId: Int, text: String, tokens: [TokenizedToken]) {
        self.sentenceId = sentenceId
        self.text = text
        self.tokens = tokens
    }

    init(json: JSONObject) {
        self.sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        self.text = JSONFieldReader.string(json, key: "text")
        self.tokens = JSONFieldReader.array(json, key: "tokens")
            .compactMap { $0 as? JSONObject }
            .map(TokenizedToken.init)
    }
}

struct TokenizeResult: Equatable, Sendable {
    let sentenceCount: Int
    let tokenCount: Int
    let sentences: [TokenizedSentence]
    let tokens: [TokenizedToken]

    init(sentences: [TokenizedSentence]) {
        self.sentences = sentences
        self.sentenceCount = sentences.count
        self.tokenCount = sentences.reduce(0) { $0 + $1.tokens.count }
        self.tokens = sentences.flatMap(\.tokens)
    }

    init(json: JSONObject) {
        self.sentences = JSONFieldReader.array(json, key: "sentences")
            .compactMap { $0 as? JSONObject }
            .map(TokenizedSentence.init)
        self.sentenceCount = JSONFieldReader.int(json, key: "sentenceCount", fallback: sentences.count)
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount", fallback: sentences.reduce(0) { $0 + $1.tokens.count })
        self.tokens = sentences.flatMap(\.tokens)
    }
}
