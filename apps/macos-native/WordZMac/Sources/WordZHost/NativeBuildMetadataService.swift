import Darwin
import Foundation

package struct NativeBuildMetadata: Codable, Equatable, Sendable {
    package let appName: String
    package let bundleIdentifier: String
    package let version: String
    package let buildNumber: String
    package let architecture: String
    package let builtAt: String
    package let gitCommit: String
    package let gitBranch: String
    package let distributionChannel: String
    package let executableSHA256: String
    package let bundlePath: String
    package let executablePath: String
    package let sourceLabel: String

    package static let empty = NativeBuildMetadata(
        appName: "WordZ",
        bundleIdentifier: "",
        version: "",
        buildNumber: "",
        architecture: "",
        builtAt: "",
        gitCommit: "",
        gitBranch: "",
        distributionChannel: "",
        executableSHA256: "",
        bundlePath: "",
        executablePath: "",
        sourceLabel: "runtime-fallback"
    )

    package init(
        appName: String,
        bundleIdentifier: String,
        version: String,
        buildNumber: String,
        architecture: String,
        builtAt: String,
        gitCommit: String,
        gitBranch: String,
        distributionChannel: String,
        executableSHA256: String,
        bundlePath: String,
        executablePath: String,
        sourceLabel: String
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.buildNumber = buildNumber
        self.architecture = architecture
        self.builtAt = builtAt
        self.gitCommit = gitCommit
        self.gitBranch = gitBranch
        self.distributionChannel = distributionChannel
        self.executableSHA256 = executableSHA256
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.sourceLabel = sourceLabel
    }

    package var buildSummary: String {
        var segments = ["SwiftUI + Swift native engine"]
        if !architecture.isEmpty {
            segments.append(architecture)
        }
        if !version.isEmpty {
            var versionSegment = "v\(version)"
            if !buildNumber.isEmpty {
                versionSegment += " (\(buildNumber))"
            }
            segments.append(versionSegment)
        } else if !buildNumber.isEmpty {
            segments.append("#\(buildNumber)")
        }
        if !gitCommit.isEmpty {
            segments.append(String(gitCommit.prefix(8)))
        }
        if !distributionChannel.isEmpty {
            segments.append(distributionChannel)
        }
        return segments.joined(separator: " · ")
    }
}

package protocol NativeBuildMetadataProviding {
    func current() -> NativeBuildMetadata
}

package struct NativeBuildMetadataService: NativeBuildMetadataProviding {
    private let bundle: Bundle
    private let fileManager: FileManager
    private let buildInfoURL: URL?

    package init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        buildInfoURL: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.buildInfoURL = buildInfoURL
    }

    package func current() -> NativeBuildMetadata {
        let fallback = fallbackMetadata()
        guard let buildInfoURL = resolvedBuildInfoURL(),
              fileManager.fileExists(atPath: buildInfoURL.path),
              let data = try? Data(contentsOf: buildInfoURL),
              let decoded = try? JSONDecoder().decode(PersistedNativeBuildInfo.self, from: data) else {
            return fallback
        }

        return NativeBuildMetadata(
            appName: decoded.appName.nonEmpty ?? fallback.appName,
            bundleIdentifier: decoded.bundleIdentifier.nonEmpty ?? fallback.bundleIdentifier,
            version: decoded.version.nonEmpty ?? fallback.version,
            buildNumber: decoded.buildNumber.nonEmpty ?? fallback.buildNumber,
            architecture: decoded.architecture.nonEmpty ?? fallback.architecture,
            builtAt: decoded.builtAt.nonEmpty ?? fallback.builtAt,
            gitCommit: decoded.gitCommit.nonEmpty ?? fallback.gitCommit,
            gitBranch: decoded.gitBranch.nonEmpty ?? fallback.gitBranch,
            distributionChannel: decoded.distributionChannel.nonEmpty ?? fallback.distributionChannel,
            executableSHA256: decoded.executableSHA256.nonEmpty ?? fallback.executableSHA256,
            bundlePath: fallback.bundlePath,
            executablePath: fallback.executablePath,
            sourceLabel: buildInfoURL.lastPathComponent
        )
    }

    private func resolvedBuildInfoURL() -> URL? {
        if let buildInfoURL {
            return buildInfoURL
        }
        return bundle.resourceURL?.appendingPathComponent("WordZMacBuildInfo.json")
    }

    private func fallbackMetadata() -> NativeBuildMetadata {
        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        let version = ((bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let buildNumber = ((bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "WordZ"
        let executablePath = bundle.executableURL?.path ?? CommandLine.arguments.first ?? ""
        return NativeBuildMetadata(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            version: version,
            buildNumber: buildNumber,
            architecture: Self.architectureIdentifier(),
            builtAt: "",
            gitCommit: ProcessInfo.processInfo.environment["WORDZ_GIT_COMMIT"] ?? "",
            gitBranch: ProcessInfo.processInfo.environment["WORDZ_GIT_BRANCH"] ?? "",
            distributionChannel: bundle.bundleURL.pathExtension.lowercased() == "app" ? "app-bundle" : "development",
            executableSHA256: "",
            bundlePath: bundle.bundleURL.path,
            executablePath: executablePath,
            sourceLabel: "runtime-fallback"
        )
    }

    private static func architectureIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}

private struct PersistedNativeBuildInfo: Decodable {
    let appName: String
    let bundleIdentifier: String
    let version: String
    let buildNumber: String
    let architecture: String
    let builtAt: String
    let gitCommit: String
    let gitBranch: String
    let distributionChannel: String
    let executableSHA256: String
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
