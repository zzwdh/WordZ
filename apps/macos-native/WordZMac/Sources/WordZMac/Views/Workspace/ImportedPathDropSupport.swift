import Foundation
import SwiftUI
import UniformTypeIdentifiers

private let importLogger = WordZTelemetry.logger(category: "Import")

enum ImportedPathDropSupport {
    static func resolveImportablePaths(from urls: [URL]) -> [String] {
        urls.compactMap { url in
            let standardizedURL = url.standardizedFileURL
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory) else {
                return nil
            }
            if isDirectory.boolValue || ImportedDocumentReadingSupport.canImport(url: standardizedURL) {
                return standardizedURL.path
            }
            return nil
        }
    }

    @MainActor
    static func extractPaths(from providers: [NSItemProvider]) async -> [String] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        return Array(NSOrderedSet(array: resolveImportablePaths(from: urls))) as? [String] ?? []
    }

    @MainActor
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                switch item {
                case let url as URL:
                    resolvedURL = url
                case let url as NSURL:
                    resolvedURL = url as URL
                case let data as Data:
                    resolvedURL = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?
                case let value as String:
                    resolvedURL = URL(string: value)
                default:
                    resolvedURL = nil
                }
                continuation.resume(returning: resolvedURL)
            }
        }
    }
}

struct ImportedPathDropModifier: ViewModifier {
    let route: NativeWindowRoute
    let onImportPaths: @MainActor ([String]) async -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .fill(Color.accentColor.opacity(0.08))
                        .overlay {
                            Label(
                                wordZText("拖入文件或文件夹以导入语料", "Drop files or folders to import corpora", mode: .system),
                                systemImage: "square.and.arrow.down"
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                Task {
                    let paths = await ImportedPathDropSupport.extractPaths(from: providers)
                    guard !paths.isEmpty else {
                        importLogger.info("import.dropIgnored route=\(route.id, privacy: .public)")
                        return
                    }
                    importLogger.info("import.dropAccepted route=\(route.id, privacy: .public) count=\(paths.count, privacy: .public)")
                    await onImportPaths(paths)
                }
                return true
            }
    }
}

extension View {
    func importedPathDropDestination(
        route: NativeWindowRoute,
        onImportPaths: @escaping @MainActor ([String]) async -> Void
    ) -> some View {
        modifier(ImportedPathDropModifier(route: route, onImportPaths: onImportPaths))
    }
}
