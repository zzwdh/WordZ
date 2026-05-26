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
}
