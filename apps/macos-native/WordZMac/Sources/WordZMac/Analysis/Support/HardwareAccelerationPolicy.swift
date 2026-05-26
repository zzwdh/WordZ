import CoreML
import Foundation
import Metal

enum NativeHardwareClass: String, Equatable, Sendable {
    case appleSilicon
    case intelMac
}

struct HardwareAccelerationSnapshot: Equatable, Sendable {
    let hardwareClass: NativeHardwareClass
    let hasMetalGPU: Bool
    let hasAppleNeuralEngine: Bool
}

enum HardwareAccelerationPolicy {
    static func currentSnapshot(
        metalDeviceProvider: () -> MTLDevice? = MTLCreateSystemDefaultDevice
    ) -> HardwareAccelerationSnapshot {
        #if arch(arm64)
        let hardwareClass: NativeHardwareClass = .appleSilicon
        let hasAppleNeuralEngine = true
        #else
        let hardwareClass: NativeHardwareClass = .intelMac
        let hasAppleNeuralEngine = false
        #endif

        return HardwareAccelerationSnapshot(
            hardwareClass: hardwareClass,
            hasMetalGPU: metalDeviceProvider() != nil,
            hasAppleNeuralEngine: hasAppleNeuralEngine
        )
    }

    static func coreMLComputeUnits(
        for providerFamily: SentimentModelProviderFamily,
        snapshot: HardwareAccelerationSnapshot = currentSnapshot()
    ) -> MLComputeUnits {
        guard snapshot.hardwareClass == .appleSilicon else {
            return snapshot.hasMetalGPU ? .cpuAndGPU : .cpuOnly
        }

        switch providerFamily {
        case .transformerCoreML:
            return .all
        case .bundledCoreML, .embeddingLogReg, .textMaxEnt, .unknown:
            return snapshot.hasAppleNeuralEngine ? .cpuAndNeuralEngine : .cpuOnly
        }
    }

    static func coreMLConfiguration(
        for providerFamily: SentimentModelProviderFamily,
        snapshot: HardwareAccelerationSnapshot = currentSnapshot()
    ) -> MLModelConfiguration {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = coreMLComputeUnits(
            for: providerFamily,
            snapshot: snapshot
        )
        return configuration
    }
}
