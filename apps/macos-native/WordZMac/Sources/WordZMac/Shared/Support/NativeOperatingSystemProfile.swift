import Foundation

struct NativeOperatingSystemProfile: Codable, Comparable, Equatable, Sendable {
    let majorVersion: Int
    let minorVersion: Int
    let patchVersion: Int

    init(
        majorVersion: Int,
        minorVersion: Int,
        patchVersion: Int
    ) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.patchVersion = patchVersion
    }

    init(_ version: OperatingSystemVersion) {
        self.init(
            majorVersion: version.majorVersion,
            minorVersion: version.minorVersion,
            patchVersion: version.patchVersion
        )
    }

    static func current(processInfo: ProcessInfo = .processInfo) -> Self {
        Self(processInfo.operatingSystemVersion)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.majorVersion != rhs.majorVersion {
            return lhs.majorVersion < rhs.majorVersion
        }
        if lhs.minorVersion != rhs.minorVersion {
            return lhs.minorVersion < rhs.minorVersion
        }
        return lhs.patchVersion < rhs.patchVersion
    }

    var displayVersion: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
}
