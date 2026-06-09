import CoreML
import XCTest
@testable import WordZWorkspaceCore

final class HardwareAccelerationPolicyTests: XCTestCase {
    func testAppleSiliconUsesAllComputeUnitsForTransformerCoreML() {
        let snapshot = HardwareAccelerationSnapshot(
            hardwareClass: .appleSilicon,
            hasMetalGPU: true,
            hasAppleNeuralEngine: true
        )

        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .transformerCoreML,
                snapshot: snapshot
            ),
            .all
        )
    }

    func testAppleSiliconKeepsSmallerCoreMLModelsOffGPUWhenNeuralEngineIsAvailable() {
        let snapshot = HardwareAccelerationSnapshot(
            hardwareClass: .appleSilicon,
            hasMetalGPU: true,
            hasAppleNeuralEngine: true
        )

        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .embeddingLogReg,
                snapshot: snapshot
            ),
            .cpuAndNeuralEngine
        )
    }

    func testIntelFallsBackToGPUWhenMetalIsAvailable() {
        let snapshot = HardwareAccelerationSnapshot(
            hardwareClass: .intelMac,
            hasMetalGPU: true,
            hasAppleNeuralEngine: false
        )

        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .transformerCoreML,
                snapshot: snapshot
            ),
            .cpuAndGPU
        )
    }

    func testIntelUsesCPUOnlyWithoutMetalGPU() {
        let snapshot = HardwareAccelerationSnapshot(
            hardwareClass: .intelMac,
            hasMetalGPU: false,
            hasAppleNeuralEngine: false
        )

        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .embeddingLogReg,
                snapshot: snapshot
            ),
            .cpuOnly
        )
    }

    func testResourcePressureKeepsCoreMLOffGPU() {
        let appleSiliconPressure = makeProfile(
            hardwareClass: .appleSilicon,
            lowPowerModeEnabled: true,
            thermalProfile: .serious
        )
        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .transformerCoreML,
                profile: appleSiliconPressure
            ),
            .cpuAndNeuralEngine
        )

        let intelPressure = makeProfile(
            hardwareClass: .intelMac,
            hasMetalGPU: true,
            lowPowerModeEnabled: true,
            thermalProfile: .serious
        )
        XCTAssertEqual(
            HardwareAccelerationPolicy.coreMLComputeUnits(
                for: .transformerCoreML,
                profile: intelPressure
            ),
            .cpuOnly
        )
    }

    func testHardwareProfileSummarizesResourceSignals() {
        let profile = makeProfile(
            hardwareClass: .appleSilicon,
            activeProcessorCount: 6,
            lowPowerModeEnabled: false,
            thermalProfile: .fair
        )

        XCTAssertFalse(profile.shouldConserveResources)
        XCTAssertEqual(profile.physicalMemoryMegabytes, 16_384)
        XCTAssertTrue(profile.summaryLine.contains("hardware=appleSilicon"))
        XCTAssertTrue(profile.summaryLine.contains("processors=6/8"))
        XCTAssertTrue(profile.summaryLine.contains("thermal=fair"))
        XCTAssertTrue(profile.summaryLine.contains("macOS=14.0.0"))
    }

    func testHardwareProfileConservesWhenLowPowerOrThermalPressureIsHigh() {
        XCTAssertTrue(
            makeProfile(
                hardwareClass: .appleSilicon,
                lowPowerModeEnabled: true,
                thermalProfile: .nominal
            ).shouldConserveResources
        )
        XCTAssertTrue(
            makeProfile(
                hardwareClass: .appleSilicon,
                lowPowerModeEnabled: false,
                thermalProfile: .serious
            ).shouldConserveResources
        )
    }

    func testWorkspaceRuntimeBudgetKeepsInteractiveTasksResponsive() {
        let budget = WorkspaceRuntimeBudgetPolicy.budget(
            for: .kwic,
            profile: makeProfile(
                hardwareClass: .appleSilicon,
                activeProcessorCount: 8,
                lowPowerModeEnabled: false,
                thermalProfile: .nominal
            )
        )

        XCTAssertEqual(budget.budgetClass, .interactive)
        XCTAssertEqual(budget.maxConcurrentWorkItems, 4)
        XCTAssertEqual(budget.recommendedBatchSize, 1_000)
        XCTAssertEqual(budget.targetDurationMs, 1_500)
        XCTAssertEqual(budget.status(for: 200), .withinTarget)
        XCTAssertEqual(budget.status(for: 2_000), .aboveTarget)
        XCTAssertEqual(budget.status(for: 4_000), .aboveSoftLimit)
    }

    func testWorkspaceRuntimeBudgetConservesForHeavyAnalysisUnderPressure() {
        let budget = WorkspaceRuntimeBudgetPolicy.budget(
            for: .topics,
            profile: makeProfile(
                hardwareClass: .appleSilicon,
                activeProcessorCount: 10,
                lowPowerModeEnabled: true,
                thermalProfile: .serious
            )
        )

        XCTAssertEqual(budget.budgetClass, .heavyAnalysis)
        XCTAssertEqual(budget.maxConcurrentWorkItems, 1)
        XCTAssertEqual(budget.recommendedBatchSize, 160)
        XCTAssertEqual(budget.targetDurationMs, 12_000)
        XCTAssertEqual(budget.memoryLimitMB, 2_048)
        XCTAssertTrue(budget.shouldConserveResources)
    }

    func testWorkspaceRunDescriptorsExposeRuntimeTaskKeys() {
        XCTAssertEqual(WorkspaceRunTaskDescriptor.stats.runtimeTaskKey, .stats)
        XCTAssertEqual(WorkspaceRunTaskDescriptor.topics.runtimeTaskKey, .topics)
        XCTAssertEqual(WorkspaceRunTaskDescriptor.sentiment.runtimeTaskKey, .sentiment)
    }

    func testNativeAnalysisRuntimeTuningConservesTopicsWorkUnderPressure() {
        let regular = NativeAnalysisRuntimeTuning.topicTuning(
            profile: makeProfile(
                hardwareClass: .appleSilicon,
                lowPowerModeEnabled: false,
                thermalProfile: .nominal
            )
        )
        XCTAssertEqual(regular.topicExactClusteringVectorLimit, 320)
        XCTAssertEqual(regular.topicApproximateClusteringIterationLimit, 32)
        XCTAssertEqual(regular.topicApproximateClusteringSeedVariants, 5)
        XCTAssertEqual(regular.topicEmbeddingCacheEntries, 2_048)

        let conserving = NativeAnalysisRuntimeTuning.topicTuning(
            profile: makeProfile(
                hardwareClass: .appleSilicon,
                lowPowerModeEnabled: true,
                thermalProfile: .serious
            )
        )
        XCTAssertEqual(conserving.topicExactClusteringVectorLimit, 240)
        XCTAssertEqual(conserving.topicApproximateClusteringIterationLimit, 24)
        XCTAssertEqual(conserving.topicApproximateClusteringSeedVariants, 3)
        XCTAssertEqual(conserving.topicEmbeddingCacheEntries, 1_024)
        XCTAssertTrue(conserving.shouldConserveResources)
    }

    func testTopicEngineUsesRuntimeTuningForApproximateThresholdAndCaches() async {
        let tuning = NativeAnalysisRuntimeTuning.topicTuning(
            profile: makeProfile(
                hardwareClass: .appleSilicon,
                lowPowerModeEnabled: true,
                thermalProfile: .serious
            )
        )
        let engine = NativeTopicEngine(runtimeTuning: tuning)

        let atLimit = await engine.shouldUseApproximateClustering(
            vectorCount: tuning.topicExactClusteringVectorLimit
        )
        let aboveLimit = await engine.shouldUseApproximateClustering(
            vectorCount: tuning.topicExactClusteringVectorLimit + 1
        )

        XCTAssertFalse(atLimit)
        XCTAssertTrue(aboveLimit)
        let maxEmbeddingCacheEntries = await engine.maxEmbeddingCacheEntries
        let maxReductionCacheEntries = await engine.maxReductionCacheEntries
        XCTAssertEqual(maxEmbeddingCacheEntries, tuning.topicEmbeddingCacheEntries)
        XCTAssertEqual(maxReductionCacheEntries, tuning.topicReductionCacheEntries)
    }

    private func makeProfile(
        hardwareClass: NativeHardwareClass,
        hasMetalGPU: Bool? = nil,
        processorCount: Int = 8,
        activeProcessorCount: Int = 8,
        physicalMemoryMB: Int = 16_384,
        lowPowerModeEnabled: Bool = false,
        thermalProfile: NativeThermalProfile = .nominal
    ) -> NativeHardwareProfile {
        NativeHardwareProfile(
            acceleration: HardwareAccelerationSnapshot(
                hardwareClass: hardwareClass,
                hasMetalGPU: hasMetalGPU ?? (hardwareClass == .appleSilicon),
                hasAppleNeuralEngine: hardwareClass == .appleSilicon
            ),
            processorCount: processorCount,
            activeProcessorCount: activeProcessorCount,
            physicalMemoryBytes: UInt64(physicalMemoryMB) * 1_048_576,
            lowPowerModeEnabled: lowPowerModeEnabled,
            thermalProfile: thermalProfile,
            operatingSystem: NativeOperatingSystemProfile(
                majorVersion: 14,
                minorVersion: 0,
                patchVersion: 0
            )
        )
    }
}
