import Foundation

enum WorkspaceRuntimeTaskKey: String, CaseIterable, Sendable {
    case stats
    case word
    case tokenize
    case topics
    case compare
    case sentiment
    case keyword
    case chiSquare
    case plot
    case ngram
    case cluster
    case kwic
    case collocate
    case locator
    case openSelectedCorpus
    case importLibrary
    case cleanLibrary
    case repairLibrary
    case restoreLibrary
    case backupLibrary
}

extension WorkspaceFeatureKey {
    var runtimeTaskKey: WorkspaceRuntimeTaskKey {
        switch self {
        case .stats:
            return .stats
        case .word:
            return .word
        case .tokenize:
            return .tokenize
        case .topics:
            return .topics
        case .compare:
            return .compare
        case .sentiment:
            return .sentiment
        case .keyword:
            return .keyword
        case .chiSquare:
            return .chiSquare
        case .plot:
            return .plot
        case .ngram:
            return .ngram
        case .cluster:
            return .cluster
        case .kwic:
            return .kwic
        case .collocate:
            return .collocate
        case .locator:
            return .locator
        }
    }
}

extension WorkspaceDetailTab {
    var runtimeTaskKey: WorkspaceRuntimeTaskKey? {
        switch self {
        case .stats:
            return .stats
        case .word:
            return .word
        case .tokenize:
            return .tokenize
        case .topics:
            return .topics
        case .compare:
            return .compare
        case .sentiment:
            return .sentiment
        case .keyword:
            return .keyword
        case .chiSquare:
            return .chiSquare
        case .plot:
            return .plot
        case .ngram:
            return .ngram
        case .cluster:
            return .cluster
        case .kwic:
            return .kwic
        case .collocate:
            return .collocate
        case .locator:
            return .locator
        case .library, .settings:
            return nil
        }
    }
}

struct WorkspaceRequestToken: Equatable, Sendable {
    let key: WorkspaceRuntimeTaskKey
    let sequence: UInt64
}

enum WorkspaceTaskExecutionPolicy: Sendable {
    case replaceLatest
    case singleFlight
    case parallel
}
