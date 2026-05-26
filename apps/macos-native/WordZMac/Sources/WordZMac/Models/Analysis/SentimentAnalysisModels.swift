import Foundation

enum SentimentLabel: String, CaseIterable, Identifiable, Codable, Sendable {
    case positive
    case neutral
    case negative

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .positive:
            return wordZText("积极", "Positive", mode: mode)
        case .neutral:
            return wordZText("中性", "Neutral", mode: mode)
        case .negative:
            return wordZText("消极", "Negative", mode: mode)
        }
    }
}

enum SentimentInputSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case openedCorpus
    case pastedText
    case kwicVisible
    case corpusCompare
    case topicSegments

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .openedCorpus:
            return wordZText("当前语料", "Opened Corpus", mode: mode)
        case .pastedText:
            return wordZText("粘贴文本", "Pasted Text", mode: mode)
        case .kwicVisible:
            return wordZText("当前 KWIC 结果", "Visible KWIC Results", mode: mode)
        case .corpusCompare:
            return wordZText("目标 / 参照语料", "Target / Reference Corpora", mode: mode)
        case .topicSegments:
            return wordZText("当前 Topics 片段", "Current Topics Segments", mode: mode)
        }
    }
}

enum SentimentAnalysisUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case document
    case sentence
    case concordanceLine
    case sourceSentence

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .document:
            return wordZText("整篇文本", "Document", mode: mode)
        case .sentence:
            return wordZText("句子", "Sentence", mode: mode)
        case .concordanceLine:
            return wordZText("索引行", "Concordance Line", mode: mode)
        case .sourceSentence:
            return wordZText("来源句子", "Source Sentence", mode: mode)
        }
    }
}

enum SentimentContextBasis: String, CaseIterable, Identifiable, Codable, Sendable {
    case visibleContext
    case fullSentenceWhenAvailable

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .visibleContext:
            return wordZText("可见上下文", "Visible Context", mode: mode)
        case .fullSentenceWhenAvailable:
            return wordZText("可用时取整句", "Full Sentence When Available", mode: mode)
        }
    }
}

enum SentimentBackendKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case lexicon
    case coreML

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .lexicon:
            return wordZText("词典规则", "Lexicon Rules", mode: mode)
        case .coreML:
            return wordZText("本地模型", "Local Model", mode: mode)
        }
    }
}

enum SentimentModelProviderFamily: String, CaseIterable, Codable, Sendable {
    case bundledCoreML
    case embeddingLogReg
    case textMaxEnt
    case transformerCoreML
    case unknown

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .bundledCoreML:
            return wordZText("内置 Core ML", "Bundled Core ML", mode: mode)
        case .embeddingLogReg:
            return wordZText("句向量 + 逻辑回归", "Sentence Embedding + Logistic Regression", mode: mode)
        case .textMaxEnt:
            return wordZText("文本最大熵", "Text MaxEnt", mode: mode)
        case .transformerCoreML:
            return wordZText("Transformer Core ML", "Transformer Core ML", mode: mode)
        case .unknown:
            return wordZText("未知", "Unknown", mode: mode)
        }
    }
}

enum SentimentModelInputSchemaKind: String, CaseIterable, Codable, Sendable {
    case text
    case denseFeatures
    case tokenizedText

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .text:
            return wordZText("原始文本", "Raw Text", mode: mode)
        case .denseFeatures:
            return wordZText("稠密特征", "Dense Features", mode: mode)
        case .tokenizedText:
            return wordZText("分词序列", "Tokenized Sequence", mode: mode)
        }
    }
}

enum SentimentInferencePath: String, CaseIterable, Codable, Sendable {
    case lexicon
    case model
    case hybrid
    case fallback

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .lexicon:
            return wordZText("词典规则", "Lexicon", mode: mode)
        case .model:
            return wordZText("本地模型", "Local Model", mode: mode)
        case .hybrid:
            return wordZText("混合判别", "Hybrid", mode: mode)
        case .fallback:
            return wordZText("回退路径", "Fallback", mode: mode)
        }
    }
}

enum SentimentDomainPackID: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case academic
    case news
    case kwic
    case mixed

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .general:
            return wordZText("通用", "General", mode: mode)
        case .academic:
            return wordZText("学术", "Academic", mode: mode)
        case .news:
            return wordZText("新闻", "News", mode: mode)
        case .kwic:
            return wordZText("KWIC", "KWIC", mode: mode)
        case .mixed:
            return wordZText("混合", "Mixed", mode: mode)
        }
    }
}

enum SentimentRuleProfileSourceKind: String, CaseIterable, Codable, Sendable {
    case builtInDefault
    case workspace
    case importedBundle
}
