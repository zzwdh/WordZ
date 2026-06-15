import Foundation
import WordZWorkspaceCore

@main
struct WordZReferenceCorpusTool {
    static func main() async {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            switch options.command {
            case .help:
                printUsage()
            case .install:
                let summary = try await ReferenceCorpusInstaller.installPreparedTextDirectory(
                    sourceDirectory: options.sourceDirectory,
                    corpusSetName: options.name,
                    userDataURL: options.userDataURL,
                    mergeIntoSingleCorpus: options.merge,
                    progress: { message in
                        print(message)
                    }
                )
                printSummary(summary)
            case .downloadInstall:
                let summary = try await EnglishReferenceCorpusDownloadInstaller.downloadAndInstall(
                    options.corpusKind,
                    userDataURL: options.userDataURL,
                    progress: { message in
                        print(message)
                    }
                )
                printSummary(summary)
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n\n", stderr)
            printUsage(to: stderr)
            exit(1)
        }
    }

    private enum Command {
        case help
        case install
        case downloadInstall
    }

    private struct Options {
        var command: Command = .help
        var sourceDirectory = URL(fileURLWithPath: "")
        var name = ""
        var corpusKind: EnglishReferenceCorpusKind = .oanc
        var userDataURL: URL?
        var merge = true
    }

    private static func parseOptions(arguments: [String]) throws -> Options {
        guard let first = arguments.first else {
            return Options(command: .help)
        }
        if first == "help" || first == "--help" || first == "-h" {
            return Options(command: .help)
        }
        guard first == "install" || first == "download-install" else {
            throw NSError(
                domain: "WordZReferenceCorpusTool",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "未知命令：\(first)"]
            )
        }

        var options = Options(command: first == "install" ? .install : .downloadInstall)
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--source":
                options.sourceDirectory = URL(fileURLWithPath: try value(after: argument, in: arguments, index: &index), isDirectory: true)
            case "--name":
                options.name = try value(after: argument, in: arguments, index: &index)
            case "--corpus":
                let rawValue = try value(after: argument, in: arguments, index: &index)
                guard let kind = EnglishReferenceCorpusKind(rawValue: rawValue) else {
                    throw NSError(
                        domain: "WordZReferenceCorpusTool",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "未知参照语料：\(rawValue)。可用值：bnc1994, oanc"]
                    )
                }
                options.corpusKind = kind
            case "--user-data":
                options.userDataURL = URL(fileURLWithPath: try value(after: argument, in: arguments, index: &index), isDirectory: true)
            case "--separate-corpora":
                options.merge = false
            case "--merge":
                options.merge = true
            default:
                throw NSError(
                    domain: "WordZReferenceCorpusTool",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "未知选项：\(argument)"]
                )
            }
            index += 1
        }

        guard options.command != .install || !options.sourceDirectory.path.isEmpty else {
            throw NSError(
                domain: "WordZReferenceCorpusTool",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "缺少 --source。"]
            )
        }
        guard options.command != .install || !options.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "WordZReferenceCorpusTool",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "缺少 --name。"]
            )
        }
        return options
    }

    private static func value(after option: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw NSError(
                domain: "WordZReferenceCorpusTool",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "\(option) 缺少值。"]
            )
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func printUsage(to stream: UnsafeMutablePointer<FILE> = stdout) {
        let text = """
        Usage:
          swift run WordZReferenceCorpusTool install --name "BNC1994 English Reference" --source /path/to/prepared/BNC1994
          swift run WordZReferenceCorpusTool install --name "OANC American English Reference" --source /path/to/prepared/OANC
          swift run WordZReferenceCorpusTool download-install --corpus bnc1994
          swift run WordZReferenceCorpusTool download-install --corpus oanc

        Options:
          --source PATH          Folder containing prepared .txt files.
          --name NAME            Name for the WordZ reference corpus set.
          --corpus VALUE         bnc1994 or oanc. Used by download-install.
          --user-data PATH       Optional WordZ user data directory.
          --merge                Merge source files into one corpus before saving the set. Default.
          --separate-corpora     Import source files as separate corpora, then save one set.
        """
        fputs(text + "\n", stream)
    }

    private static func printSummary(_ summary: ReferenceCorpusInstallSummary) {
        print("")
        print("Installed reference corpus set")
        print("Name: \(summary.corpusSetName)")
        print("User data: \(summary.userDataPath)")
        print("Imported corpora: \(summary.importedCount)")
        print("Source files: \(summary.sourceFileCount)")
        if summary.skippedCount > 0 || !summary.failureMessages.isEmpty {
            print("Skipped: \(summary.skippedCount)")
            for message in summary.failureMessages {
                print("- \(message)")
            }
        }
    }
}
