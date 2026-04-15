import Foundation

struct TokenizedToken: Identifiable, Hashable, Sendable {
    let original: String
    let normalized: String
    let sentenceId: Int
    let tokenIndex: Int
    let annotations: TokenLinguisticAnnotations

    var id: String { "\(sentenceId)-\(tokenIndex)" }

    init(
        original: String,
        normalized: String,
        sentenceId: Int,
        tokenIndex: Int,
        annotations: TokenLinguisticAnnotations = .empty
    ) {
        self.original = original
        self.normalized = normalized
        self.sentenceId = sentenceId
        self.tokenIndex = tokenIndex
        self.annotations = annotations
    }

    init(json: JSONObject) {
        self.original = JSONFieldReader.string(json, key: "original")
        self.normalized = JSONFieldReader.string(json, key: "normalized")
        self.sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        self.tokenIndex = JSONFieldReader.int(json, key: "tokenIndex")
        if let annotations = json["annotations"] as? JSONObject {
            self.annotations = TokenLinguisticAnnotations(
                script: TokenScript(
                    rawValue: JSONFieldReader.string(annotations, key: "script", fallback: TokenScript.other.rawValue)
                ) ?? .other,
                lemma: {
                    let lemma = JSONFieldReader.string(annotations, key: "lemma")
                    return lemma.isEmpty ? nil : lemma
                }(),
                lexicalClass: {
                    let raw = JSONFieldReader.string(annotations, key: "lexicalClass")
                    return TokenLexicalClass(rawValue: raw)
                }()
            )
        } else {
            self.annotations = TokenLinguisticAnnotations(
                script: LinguisticAnnotationSupport.classifyScript(in: original),
                lemma: nil,
                lexicalClass: nil
            )
        }
    }

    var jsonObject: JSONObject {
        [
            "original": original,
            "normalized": normalized,
            "sentenceId": sentenceId,
            "tokenIndex": tokenIndex,
            "annotations": annotations.jsonObject
        ]
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

    var jsonObject: JSONObject {
        [
            "sentenceId": sentenceId,
            "text": text,
            "tokens": tokens.map(\.jsonObject)
        ]
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
