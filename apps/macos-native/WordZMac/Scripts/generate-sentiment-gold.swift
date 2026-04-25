#!/usr/bin/env swift

import Foundation

struct GoldExample: Codable {
    let id: String
    let split: String
    let domain: String
    let label: String
    let text: String
    let tags: [String]?
}

struct GoldManifest: Codable {
    let version: String
    let totalExamples: Int
    let countsBySplit: [String: Int]
    let countsByDomain: [String: Int]
    let countsByLabel: [String: Int]
    let countsByTag: [String: Int]?
    let notes: String
}

enum ScriptFailure: LocalizedError {
    case missingArgument(String)
    case invalidInputDataset

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidInputDataset:
            return "The input dataset is empty or malformed."
        }
    }
}

private let splits: [(name: String, count: Int)] = [
    ("train", 18),
    ("validation", 6),
    ("test", 6)
]

private let domains = ["general", "academic", "news", "kwic"]
private let labels = ["positive", "neutral", "negative"]

enum SentimentGoldGenerator {
    static func run(arguments: [String]) throws {
        let options = try parseOptions(arguments)
        let examples = try loadExamples(using: options)
        let manifest = GoldManifest(
            version: options.version,
            totalExamples: examples.count,
            countsBySplit: counts(for: examples, keyPath: \.split),
            countsByDomain: counts(for: examples, keyPath: \.domain),
            countsByLabel: counts(for: examples, keyPath: \.label),
            countsByTag: tagCounts(for: examples),
            notes: options.notes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let manifestURL = URL(fileURLWithPath: options.manifestPath)
        if let outputPath = options.outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(examples).write(to: outputURL)
            print("Generated \(examples.count) examples at \(outputURL.path)")
        }
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(manifest).write(to: manifestURL)

        print("Wrote manifest to \(manifestURL.path)")
    }

    private static func parseOptions(_ arguments: [String]) throws -> (
        outputPath: String?,
        inputPath: String?,
        manifestPath: String,
        version: String,
        notes: String
    ) {
        var outputPath: String?
        var inputPath: String?
        var manifestPath: String?
        var version = "v2"
        var notes = defaultNotes(for: version, templated: true)
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--output":
                index += 1
                outputPath = safeArgument(at: index, in: arguments)
            case "--input":
                index += 1
                inputPath = safeArgument(at: index, in: arguments)
            case "--manifest":
                index += 1
                manifestPath = safeArgument(at: index, in: arguments)
            case "--version":
                index += 1
                version = safeArgument(at: index, in: arguments) ?? version
                notes = defaultNotes(for: version, templated: inputPath == nil)
            case "--notes":
                index += 1
                notes = safeArgument(at: index, in: arguments) ?? notes
            default:
                break
            }
            index += 1
        }

        guard let manifestPath else { throw ScriptFailure.missingArgument("--manifest") }
        guard outputPath != nil || inputPath != nil else {
            throw ScriptFailure.missingArgument("--output or --input")
        }
        return (outputPath, inputPath, manifestPath, version, notes)
    }

    private static func safeArgument(at index: Int, in arguments: [String]) -> String? {
        guard arguments.indices.contains(index) else { return nil }
        return arguments[index]
    }

    private static func counts(
        for examples: [GoldExample],
        keyPath: KeyPath<GoldExample, String>
    ) -> [String: Int] {
        Dictionary(grouping: examples, by: { $0[keyPath: keyPath] })
            .mapValues(\.count)
    }

    private static func tagCounts(for examples: [GoldExample]) -> [String: Int]? {
        let counts = examples
            .flatMap { $0.tags ?? [] }
            .reduce(into: [String: Int]()) { partial, tag in
                partial[tag, default: 0] += 1
            }
        return counts.isEmpty ? nil : counts
    }

    private static func loadExamples(
        using options: (outputPath: String?, inputPath: String?, manifestPath: String, version: String, notes: String)
    ) throws -> [GoldExample] {
        if let inputPath = options.inputPath {
            let inputURL = URL(fileURLWithPath: inputPath)
            let data = try Data(contentsOf: inputURL)
            let examples = try JSONDecoder().decode([GoldExample].self, from: data)
            guard !examples.isEmpty else {
                throw ScriptFailure.invalidInputDataset
            }
            return examples
        }
        return buildExamples()
    }

    private static func defaultNotes(
        for version: String,
        templated: Bool
    ) -> String {
        let normalizedVersion = version.lowercased()
        if normalizedVersion == "v3" || normalizedVersion == "3" {
            return "Manually adjudicated English news-oriented benchmark focused on procedural neutrality, quoted language, reported speech, commentary, and stance framing."
        }
        if templated {
            return "Templated English-tuned starter gold pack for benchmark/calibration. Replace or augment with manually adjudicated corpus examples for production evaluation."
        }
        return "Curated sentiment benchmark fixture."
    }

    private static func buildExamples() -> [GoldExample] {
        var examples: [GoldExample] = []
        for domain in domains {
            for label in labels {
                let texts = textsForDomain(domain, label: label)
                precondition(texts.count == 30, "Expected 30 examples for \(domain)/\(label), got \(texts.count)")

                var offset = 0
                for split in splits {
                    let slice = texts[offset ..< offset + split.count]
                    examples.append(contentsOf: slice.enumerated().map { index, text in
                        GoldExample(
                            id: "v2-\(domain)-\(label)-\(split.name)-\(String(format: "%03d", index + 1))",
                            split: split.name,
                            domain: domain,
                            label: label,
                            text: text,
                            tags: nil
                        )
                    })
                    offset += split.count
                }
            }
        }
        return examples
    }

    private static func textsForDomain(_ domain: String, label: String) -> [String] {
        switch (domain, label) {
        case ("general", "positive"):
            return buildGeneralPositive()
        case ("general", "neutral"):
            return buildGeneralNeutral()
        case ("general", "negative"):
            return buildGeneralNegative()
        case ("academic", "positive"):
            return buildAcademicPositive()
        case ("academic", "neutral"):
            return buildAcademicNeutral()
        case ("academic", "negative"):
            return buildAcademicNegative()
        case ("news", "positive"):
            return buildNewsPositive()
        case ("news", "neutral"):
            return buildNewsNeutral()
        case ("news", "negative"):
            return buildNewsNegative()
        case ("kwic", "positive"):
            return buildKWICPositive()
        case ("kwic", "neutral"):
            return buildKWICNeutral()
        case ("kwic", "negative"):
            return buildKWICNegative()
        default:
            preconditionFailure("Unsupported domain/label combination: \(domain) / \(label)")
        }
    }

    private static func buildGeneralPositive() -> [String] {
        let subjects = [
            "The interface", "The update", "The tutorial", "The export panel", "The concordance view",
            "The search flow", "The workspace layout", "The results table", "The import guide", "The filter panel"
        ]
        let descriptors = [
            "intuitive", "clear", "stable", "reliable", "useful",
            "efficient", "helpful", "smooth", "well designed", "easy to follow"
        ]
        let benefits = [
            "for beginners", "during annotation", "for classroom demos", "for longer sessions", "in daily use",
            "for comparative work", "for quick checks", "for writing tasks", "for corpus review", "for repeated searches"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let descriptor = descriptors[(index * 3) % descriptors.count]
            let benefit = benefits[(index * 7) % benefits.count]
            switch index % 3 {
            case 0:
                return "\(subject) is \(descriptor) and especially helpful \(benefit)."
            case 1:
                return "\(subject) feels \(descriptor) and works reliably \(benefit)."
            default:
                return "Users found \(subject.lowercased()) \(descriptor) and genuinely useful \(benefit)."
            }
        }
    }

    private static func buildGeneralNeutral() -> [String] {
        let subjects = [
            "The dashboard", "The report", "The package", "The window", "The article",
            "The project", "The menu", "The table", "The chapter", "The corpus browser"
        ]
        let verbs = [
            "shows", "contains", "lists", "includes", "stores",
            "presents", "displays", "records", "uses", "opens"
        ]
        let objects = [
            "token totals and document counts", "three sections and two appendices", "CSV and JSON export options",
            "the current filter state", "dates and locations of the hearings", "metadata for each document",
            "one settings window and one help page", "the selected corpus name", "frequency columns and rank values",
            "reference notes for the examples"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let verb = verbs[(index * 3) % verbs.count]
            let object = objects[(index * 5) % objects.count]
            switch index % 3 {
            case 0:
                return "\(subject) \(verb) \(object)."
            case 1:
                return "\(subject) \(verb) \(object) for the current session."
            default:
                return "In the current workspace, \(subject.lowercased()) \(verb) \(object)."
            }
        }
    }

    private static func buildGeneralNegative() -> [String] {
        let subjects = [
            "The app", "The workflow", "The warning message", "The explanation", "The export routine",
            "The setup guide", "The search panel", "The build step", "The result preview", "The import flow"
        ]
        let descriptors = [
            "slow", "confusing", "unstable", "misleading", "problematic",
            "fragile", "noisy", "unreliable", "awkward", "hard to trust"
        ]
        let issues = [
            "during repeated use", "for new users", "when projects grow larger", "under deadline pressure", "in shared labs",
            "during classroom demos", "when exports are repeated", "for quick review", "for corpus cleanup", "on older machines"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let descriptor = descriptors[(index * 3) % descriptors.count]
            let issue = issues[(index * 5) % issues.count]
            switch index % 3 {
            case 0:
                return "\(subject) is \(descriptor) and often frustrating \(issue)."
            case 1:
                return "\(subject) looks useful but becomes \(descriptor) \(issue)."
            default:
                return "Users described \(subject.lowercased()) as \(descriptor) and risky \(issue)."
            }
        }
    }

    private static func buildAcademicPositive() -> [String] {
        let subjects = [
            "The method", "The analysis", "The framework", "The corpus design", "The annotation scheme",
            "The experimental setup", "The scoring strategy", "The comparison baseline", "The sampling plan", "The evidence base"
        ]
        let descriptors = [
            "robust", "effective", "well motivated", "carefully designed", "valuable",
            "promising", "useful", "systematic", "insightful", "reliable"
        ]
        let outcomes = [
            "for corpus research", "for replication work", "for pedagogy", "for classroom use", "for longitudinal comparison",
            "for discourse analysis", "for interpretive consistency", "for mixed-method studies", "for low-noise baselines", "for follow-up experiments"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let descriptor = descriptors[(index * 3) % descriptors.count]
            let outcome = outcomes[(index * 7) % outcomes.count]
            switch index % 3 {
            case 0:
                return "\(subject) provides a \(descriptor) baseline \(outcome)."
            case 1:
                return "\(subject) appears \(descriptor) and particularly useful \(outcome)."
            default:
                return "The reviewers described \(subject.lowercased()) as \(descriptor) \(outcome)."
            }
        }
    }

    private static func buildAcademicNeutral() -> [String] {
        let subjects = [
            "The study", "The corpus", "Section 3", "The appendix", "The experiment",
            "The sample", "The article", "The table", "The dataset", "The procedure"
        ]
        let verbs = [
            "examines", "reports", "describes", "outlines", "includes",
            "uses", "summarizes", "compares", "lists", "documents"
        ]
        let objects = [
            "120 essays collected in 2024", "the annotation procedure in detail", "token counts before normalization",
            "interviews, essays, and news reports", "the corpus selection criteria", "the coding protocol for the pilot set",
            "the preliminary results from two groups", "frequency tables for the target corpus", "the distribution of genres in the sample",
            "the sequence of preprocessing steps"
        ]
        let hedges = [
            "The findings are preliminary and should be interpreted cautiously.",
            "The results remain provisional pending further study.",
            "The analysis is descriptive rather than evaluative in this section.",
            "The paper reports initial observations without broader claims.",
            "The interpretation remains cautious because additional data are needed."
        ]
        return makeThirtyExamples { index in
            if index < hedges.count {
                return hedges[index]
            }
            let adjusted = index - hedges.count
            let subject = subjects[adjusted % subjects.count]
            let verb = verbs[(adjusted * 3) % verbs.count]
            let object = objects[(adjusted * 5) % objects.count]
            switch adjusted % 3 {
            case 0:
                return "\(subject) \(verb) \(object)."
            case 1:
                return "\(subject) \(verb) \(object) in the current study."
            default:
                return "In this paper, \(subject.lowercased()) \(verb) \(object)."
            }
        }
    }

    private static func buildAcademicNegative() -> [String] {
        let subjects = [
            "The evidence", "The interpretation", "The sample", "The model", "The annotation scheme",
            "The baseline", "The argument", "The dataset", "The comparison", "The procedure"
        ]
        let descriptors = [
            "limited", "weak", "inconclusive", "fragile", "under-specified",
            "biased", "uncertain", "problematic", "incomplete", "hard to generalize"
        ]
        let outcomes = [
            "for low-resource domains", "for longitudinal claims", "for strong causal arguments", "for reliable replication",
            "for classroom transfer", "for narrow subcorpora", "for broader theoretical claims", "for fine-grained annotation",
            "for balanced comparison", "for robust inference"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let descriptor = descriptors[(index * 3) % descriptors.count]
            let outcome = outcomes[(index * 7) % outcomes.count]
            switch index % 3 {
            case 0:
                return "\(subject) remains \(descriptor) \(outcome)."
            case 1:
                return "\(subject) appears \(descriptor) and somewhat risky \(outcome)."
            default:
                return "The paper notes that \(subject.lowercased()) is \(descriptor) \(outcome)."
            }
        }
    }

    private static func buildNewsPositive() -> [String] {
        let subjects = [
            "Officials", "Teachers", "Parents", "Analysts", "Local leaders",
            "The mayor", "Reviewers", "Investors", "Observers", "Organizers"
        ]
        let verbs = [
            "praised", "welcomed", "commended", "backed", "endorsed",
            "supported", "highlighted", "described", "celebrated", "hailed"
        ]
        let objects = [
            "the program as a successful response", "the rollout as a helpful change", "the platform as a reliable tool",
            "the initiative as a useful step", "the update as a practical improvement", "the proposal as a constructive measure",
            "the training package as a strong resource", "the report as an encouraging sign", "the pilot as a worthwhile investment",
            "the reform as a positive signal"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let verb = verbs[(index * 3) % verbs.count]
            let object = objects[(index * 5) % objects.count]
            switch index % 3 {
            case 0:
                return "\(subject) \(verb) \(object)."
            case 1:
                return "\(subject) \(verb) \(object) after the announcement."
            default:
                return "In early coverage, \(subject.lowercased()) \(verb) \(object)."
            }
        }
    }

    private static func buildNewsNeutral() -> [String] {
        let subjects = [
            "The committee", "The meeting", "The bill", "The document", "The hearing",
            "The agency", "The council", "The report", "The statement", "The update"
        ]
        let verbs = [
            "released", "began", "introduced", "published", "scheduled",
            "issued", "held", "announced", "recorded", "filed"
        ]
        let objects = [
            "the document after the vote", "at 9 a.m. and lasted two hours", "the measure on Tuesday", "the revised figures on Wednesday",
            "a follow-up meeting for next month", "the notice before noon", "the final agenda for the session", "the timeline for the next phase",
            "the attendance totals for the event", "the public comment period"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let verb = verbs[(index * 3) % verbs.count]
            let object = objects[(index * 5) % objects.count]
            switch index % 3 {
            case 0:
                return "\(subject) \(verb) \(object)."
            case 1:
                return "\(subject) \(verb) \(object) according to the filing."
            default:
                return "Reporters noted that \(subject.lowercased()) \(verb) \(object)."
            }
        }
    }

    private static func buildNewsNegative() -> [String] {
        let subjects = [
            "Opposition leaders", "Critics", "Analysts", "Officials", "Residents",
            "Commentators", "The report", "The statement", "Campaigners", "Observers"
        ]
        let verbs = [
            "warned of", "slammed", "criticized", "raised concern about", "described",
            "called out", "flagged", "blamed", "condemned", "linked"
        ]
        let objects = [
            "a worsening crisis", "the proposal as costly and risky", "the rollout as deeply problematic",
            "a severe decline in services", "the plan as controversial and harmful", "serious risks for schools",
            "mounting concern among local families", "a fragile recovery", "persistent pressure on staff", "a damaging policy shift"
        ]
        return makeThirtyExamples { index in
            let subject = subjects[index % subjects.count]
            let verb = verbs[(index * 3) % verbs.count]
            let object = objects[(index * 5) % objects.count]
            switch index % 3 {
            case 0:
                return "\(subject) \(verb) \(object)."
            case 1:
                return "\(subject) \(verb) \(object) after the briefing."
            default:
                return "In follow-up coverage, \(subject.lowercased()) \(verb) \(object)."
            }
        }
    }

    private static func buildKWICPositive() -> [String] {
        let cues = [
            "widely praised by teachers", "remarkably effective in practice", "clear and useful for beginners",
            "especially helpful in class", "strong support from reviewers", "easy to follow in context",
            "consistently reliable across tasks", "highly valuable for revision", "well received by students", "surprisingly stable over time"
        ]
        return makeThirtyExamples { index in
            let cue = cues[index % cues.count]
            switch index % 3 {
            case 0:
                return cue
            case 1:
                return "reported as \(cue)"
            default:
                return "considered \(cue)"
            }
        }
    }

    private static func buildKWICNeutral() -> [String] {
        let cues = [
            "as shown in Table 2", "in the current study", "for the target corpus",
            "after tokenization was complete", "according to the appendix", "within the selected subcorpus",
            "during the second phase", "for the reference set", "in the pilot sample", "under the present design"
        ]
        return makeThirtyExamples { index in
            let cue = cues[index % cues.count]
            switch index % 3 {
            case 0:
                return cue
            case 1:
                return "noted \(cue)"
            default:
                return "reported \(cue)"
            }
        }
    }

    private static func buildKWICNegative() -> [String] {
        let cues = [
            "highly problematic for learners", "serious risk to stability", "costly and risky for schools",
            "widely criticized in reports", "difficult to justify in context", "deeply harmful for trust",
            "markedly unstable over time", "a persistent source of concern", "hard to interpret reliably", "severely limited in scope"
        ]
        return makeThirtyExamples { index in
            let cue = cues[index % cues.count]
            switch index % 3 {
            case 0:
                return cue
            case 1:
                return "described as \(cue)"
            default:
                return "viewed as \(cue)"
            }
        }
    }

    private static func makeThirtyExamples(
        builder: (Int) -> String
    ) -> [String] {
        (0..<30).map(builder)
    }
}

do {
    try SentimentGoldGenerator.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
