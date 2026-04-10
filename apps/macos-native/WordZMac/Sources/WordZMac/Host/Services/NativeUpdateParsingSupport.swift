import Foundation

struct ReleaseVersionComparator {
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = normalizedParts(for: latest)
        let currentParts = normalizedParts(for: current)
        let maxCount = max(latestParts.count, currentParts.count)
        for index in 0..<maxCount {
            let lhs = index < latestParts.count ? latestParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    private static func normalizedParts(for version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "")
            .split(separator: ".")
            .compactMap { Int($0.filter(\.isNumber)) }
    }
}

enum GitHubReleaseAssetSelector {
    static func preferredAsset(from assets: [NativeUpdateAsset]) -> NativeUpdateAsset? {
        let installables = assets.filter { asset in
            let lowercased = asset.name.lowercased()
            return lowercased.hasSuffix(".dmg") || lowercased.hasSuffix(".zip")
        }
        guard !installables.isEmpty else { return nil }

        #if arch(arm64)
        let architectureHints = ["universal", "arm64", "apple-silicon", "mac"]
        #else
        let architectureHints = ["universal", "x86_64", "intel", "mac"]
        #endif

        for hint in architectureHints {
            if let matched = installables.first(where: { $0.name.lowercased().contains(hint) }) {
                return matched
            }
        }

        if let dmg = installables.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
            return dmg
        }
        return installables.first
    }
}

enum GitHubReleasePayloadParser {
    static func errorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String,
            !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return message
    }

    static func parse(_ object: [String: Any], currentVersion: String) -> NativeUpdateCheckResult {
        let latestVersion = (object["tag_name"] as? String)
            ?? (object["name"] as? String)
            ?? currentVersion
        let releaseTitle = (object["name"] as? String) ?? latestVersion
        let releaseURL = (object["html_url"] as? String) ?? "https://github.com/zzwdh/WordZ/releases"
        let publishedAt = (object["published_at"] as? String) ?? ""
        let updateAvailable = ReleaseVersionComparator.isNewer(latestVersion, than: currentVersion)
        let assets = ((object["assets"] as? [[String: Any]]) ?? []).compactMap { assetObject -> NativeUpdateAsset? in
            let name = (assetObject["name"] as? String) ?? ""
            let downloadURL = (assetObject["browser_download_url"] as? String) ?? ""
            guard !name.isEmpty, !downloadURL.isEmpty else { return nil }
            return NativeUpdateAsset(name: name, downloadURL: downloadURL)
        }
        let asset = GitHubReleaseAssetSelector.preferredAsset(from: assets)
        let notes = normalizedReleaseNotes(from: (object["body"] as? String) ?? "")
        let statusMessage: String
        if updateAvailable {
            if let asset {
                statusMessage = "发现新版本 \(latestVersion)，可下载更新包 \(asset.name)。"
            } else {
                statusMessage = "发现新版本 \(latestVersion)，但当前没有可下载的 mac 安装包。"
            }
        } else {
            statusMessage = "当前已是最新版本（\(currentVersion)）。"
        }

        return NativeUpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseURL: releaseURL,
            statusMessage: statusMessage,
            updateAvailable: updateAvailable,
            asset: asset,
            releaseTitle: releaseTitle,
            publishedAt: publishedAt,
            releaseNotes: notes
        )
    }

    static func normalizedReleaseNotes(from body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .map { line in
                var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                while let first = cleaned.first, ["#", "-", "*", "+"].contains(first) {
                    cleaned.removeFirst()
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
    }
}
