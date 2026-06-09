import Foundation

enum WorkspaceRuntimeBudgetClass: String, Codable, Equatable, Sendable {
    case interactive
    case balanced
    case heavyAnalysis
    case importExport
    case maintenance
}

enum WorkspaceRuntimeBudgetStatus: String, Codable, Equatable, Sendable {
    case withinTarget
    case aboveTarget
    case aboveSoftLimit
}

struct WorkspaceRuntimeTaskBudget: Codable, Equatable, Sendable {
    let key: WorkspaceRuntimeTaskKey
    let budgetClass: WorkspaceRuntimeBudgetClass
    let maxConcurrentWorkItems: Int
    let recommendedBatchSize: Int
    let targetDurationMs: Int
    let softDurationLimitMs: Int
    let memoryLimitMB: Int
    let shouldConserveResources: Bool
    let hardwareSummary: String

    func status(for durationMs: Int) -> WorkspaceRuntimeBudgetStatus {
        if durationMs > softDurationLimitMs {
            return .aboveSoftLimit
        }
        if durationMs > targetDurationMs {
            return .aboveTarget
        }
        return .withinTarget
    }
}

enum WorkspaceRuntimeBudgetPolicy {
    static func budget(
        for key: WorkspaceRuntimeTaskKey,
        profile: NativeHardwareProfile = HardwareAccelerationPolicy.currentHardwareProfile()
    ) -> WorkspaceRuntimeTaskBudget {
        let budgetClass = budgetClass(for: key)
        let concurrency = maxConcurrentWorkItems(
            budgetClass: budgetClass,
            profile: profile
        )
        let batchSize = recommendedBatchSize(
            budgetClass: budgetClass,
            profile: profile
        )
        let targetDurationMs = targetDuration(
            budgetClass: budgetClass,
            profile: profile
        )
        let memoryLimitMB = memoryLimit(
            budgetClass: budgetClass,
            profile: profile
        )

        return WorkspaceRuntimeTaskBudget(
            key: key,
            budgetClass: budgetClass,
            maxConcurrentWorkItems: concurrency,
            recommendedBatchSize: batchSize,
            targetDurationMs: targetDurationMs,
            softDurationLimitMs: targetDurationMs * 2,
            memoryLimitMB: memoryLimitMB,
            shouldConserveResources: profile.shouldConserveResources,
            hardwareSummary: profile.summaryLine
        )
    }

    static func budgetClass(for key: WorkspaceRuntimeTaskKey) -> WorkspaceRuntimeBudgetClass {
        switch key {
        case .stats, .word, .tokenize, .plot, .kwic, .locator:
            return .interactive
        case .ngram, .cluster, .collocate, .compare, .keyword, .chiSquare:
            return .balanced
        case .topics, .sentiment:
            return .heavyAnalysis
        case .openSelectedCorpus, .importLibrary:
            return .importExport
        case .cleanLibrary, .repairLibrary, .restoreLibrary, .backupLibrary:
            return .maintenance
        }
    }

    private static func maxConcurrentWorkItems(
        budgetClass: WorkspaceRuntimeBudgetClass,
        profile: NativeHardwareProfile
    ) -> Int {
        let activeCores = max(1, profile.activeProcessorCount)
        let regularLimit: Int
        switch budgetClass {
        case .interactive:
            regularLimit = min(4, max(2, activeCores - 1))
        case .balanced:
            regularLimit = min(6, max(2, activeCores - 1))
        case .heavyAnalysis:
            regularLimit = min(8, max(2, activeCores))
        case .importExport, .maintenance:
            regularLimit = min(3, max(1, activeCores / 2))
        }

        guard profile.shouldConserveResources else {
            return regularLimit
        }
        switch budgetClass {
        case .interactive:
            return min(2, regularLimit)
        case .balanced, .heavyAnalysis, .importExport, .maintenance:
            return 1
        }
    }

    private static func recommendedBatchSize(
        budgetClass: WorkspaceRuntimeBudgetClass,
        profile: NativeHardwareProfile
    ) -> Int {
        let base: Int
        switch budgetClass {
        case .interactive:
            base = 1_000
        case .balanced:
            base = 640
        case .heavyAnalysis:
            base = 320
        case .importExport:
            base = 500
        case .maintenance:
            base = 250
        }

        guard profile.shouldConserveResources else {
            return base
        }
        return max(100, base / 2)
    }

    private static func targetDuration(
        budgetClass: WorkspaceRuntimeBudgetClass,
        profile: NativeHardwareProfile
    ) -> Int {
        let base: Int
        switch budgetClass {
        case .interactive:
            base = 1_500
        case .balanced:
            base = 3_000
        case .heavyAnalysis:
            base = 6_000
        case .importExport:
            base = 4_000
        case .maintenance:
            base = 8_000
        }
        return profile.shouldConserveResources ? base * 2 : base
    }

    private static func memoryLimit(
        budgetClass: WorkspaceRuntimeBudgetClass,
        profile: NativeHardwareProfile
    ) -> Int {
        let availableMB = max(512, profile.physicalMemoryMegabytes)
        let classCap: Int
        switch budgetClass {
        case .interactive:
            classCap = 1_024
        case .balanced:
            classCap = 2_048
        case .heavyAnalysis:
            classCap = 4_096
        case .importExport:
            classCap = 2_048
        case .maintenance:
            classCap = 1_536
        }

        let profileCap = profile.shouldConserveResources ? classCap / 2 : classCap
        return max(256, min(profileCap, availableMB / 4))
    }
}
