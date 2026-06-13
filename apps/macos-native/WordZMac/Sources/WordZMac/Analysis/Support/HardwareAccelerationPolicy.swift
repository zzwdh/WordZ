import CoreML
import Foundation
import Metal

enum NativeHardwareClass: String, Codable, Equatable, Sendable {
    case appleSilicon
    case intelMac
}

struct HardwareAccelerationSnapshot: Codable, Equatable, Sendable {
    let hardwareClass: NativeHardwareClass
    let hasMetalGPU: Bool
    let hasAppleNeuralEngine: Bool
}

enum NativeThermalProfile: String, Codable, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .unknown
        }
    }

    var shouldConserveResources: Bool {
        switch self {
        case .serious, .critical:
            return true
        case .nominal, .fair, .unknown:
            return false
        }
    }
}

struct NativeHardwareProfile: Codable, Equatable, Sendable {
    let acceleration: HardwareAccelerationSnapshot
    let processorCount: Int
    let activeProcessorCount: Int
    let physicalMemoryBytes: UInt64
    let lowPowerModeEnabled: Bool
    let thermalProfile: NativeThermalProfile
    let operatingSystem: NativeOperatingSystemProfile

    init(
        acceleration: HardwareAccelerationSnapshot,
        processorCount: Int,
        activeProcessorCount: Int,
        physicalMemoryBytes: UInt64,
        lowPowerModeEnabled: Bool,
        thermalProfile: NativeThermalProfile,
        operatingSystem: NativeOperatingSystemProfile
    ) {
        self.acceleration = acceleration
        self.processorCount = max(1, processorCount)
        self.activeProcessorCount = max(1, activeProcessorCount)
        self.physicalMemoryBytes = physicalMemoryBytes
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.thermalProfile = thermalProfile
        self.operatingSystem = operatingSystem
    }

    static func current(
        processInfo: ProcessInfo = .processInfo,
        metalDeviceProvider: () -> MTLDevice? = MTLCreateSystemDefaultDevice
    ) -> Self {
        Self(
            acceleration: HardwareAccelerationPolicy.currentSnapshot(
                metalDeviceProvider: metalDeviceProvider
            ),
            processorCount: processInfo.processorCount,
            activeProcessorCount: processInfo.activeProcessorCount,
            physicalMemoryBytes: processInfo.physicalMemory,
            lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalProfile: NativeThermalProfile(processInfo.thermalState),
            operatingSystem: NativeOperatingSystemProfile.current(processInfo: processInfo)
        )
    }

    var physicalMemoryMegabytes: Int {
        Int(physicalMemoryBytes / 1_048_576)
    }

    var shouldConserveResources: Bool {
        lowPowerModeEnabled
            || thermalProfile.shouldConserveResources
            || activeProcessorCount < max(1, processorCount / 2)
    }

    var summaryLine: String {
        [
            "hardware=\(acceleration.hardwareClass.rawValue)",
            "metal=\(acceleration.hasMetalGPU)",
            "ane=\(acceleration.hasAppleNeuralEngine)",
            "processors=\(activeProcessorCount)/\(processorCount)",
            "memoryMB=\(physicalMemoryMegabytes)",
            "lowPower=\(lowPowerModeEnabled)",
            "thermal=\(thermalProfile.rawValue)",
            "macOS=\(operatingSystem.displayVersion)"
        ].joined(separator: " ")
    }
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

    static func currentHardwareProfile(
        processInfo: ProcessInfo = .processInfo,
        metalDeviceProvider: () -> MTLDevice? = MTLCreateSystemDefaultDevice
    ) -> NativeHardwareProfile {
        NativeHardwareProfile.current(
            processInfo: processInfo,
            metalDeviceProvider: metalDeviceProvider
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

    static func coreMLComputeUnits(
        for providerFamily: SentimentModelProviderFamily,
        profile: NativeHardwareProfile
    ) -> MLComputeUnits {
        guard profile.shouldConserveResources else {
            return coreMLComputeUnits(
                for: providerFamily,
                snapshot: profile.acceleration
            )
        }

        guard profile.acceleration.hardwareClass == .appleSilicon else {
            return .cpuOnly
        }

        switch providerFamily {
        case .transformerCoreML:
            return profile.acceleration.hasAppleNeuralEngine ? .cpuAndNeuralEngine : .cpuOnly
        case .bundledCoreML, .embeddingLogReg, .textMaxEnt, .unknown:
            return profile.acceleration.hasAppleNeuralEngine ? .cpuAndNeuralEngine : .cpuOnly
        }
    }

    static func coreMLConfiguration(
        for providerFamily: SentimentModelProviderFamily
    ) -> MLModelConfiguration {
        coreMLConfiguration(
            for: providerFamily,
            profile: currentHardwareProfile()
        )
    }

    static func coreMLConfiguration(
        for providerFamily: SentimentModelProviderFamily,
        snapshot: HardwareAccelerationSnapshot
    ) -> MLModelConfiguration {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = coreMLComputeUnits(
            for: providerFamily,
            snapshot: snapshot
        )
        return configuration
    }

    static func coreMLConfiguration(
        for providerFamily: SentimentModelProviderFamily,
        profile: NativeHardwareProfile
    ) -> MLModelConfiguration {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = coreMLComputeUnits(
            for: providerFamily,
            profile: profile
        )
        return configuration
    }

    static func coreMLComputeUnitsLabel(_ units: MLComputeUnits) -> String {
        switch units {
        case .all:
            return "all"
        case .cpuAndGPU:
            return "cpuAndGPU"
        case .cpuOnly:
            return "cpuOnly"
        case .cpuAndNeuralEngine:
            return "cpuAndNeuralEngine"
        @unknown default:
            return "unknown"
        }
    }

    static func coreMLComputeUnitsLabel(
        for providerFamily: SentimentModelProviderFamily,
        profile: NativeHardwareProfile = currentHardwareProfile()
    ) -> String {
        coreMLComputeUnitsLabel(
            coreMLComputeUnits(
                for: providerFamily,
                profile: profile
            )
        )
    }
}
