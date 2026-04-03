import Foundation

@MainActor
final class ChiSquarePageViewModel: ObservableObject {
    @Published var a = ""
    @Published var b = ""
    @Published var c = ""
    @Published var d = ""
    @Published var useYates = false
    @Published var scene: ChiSquareSceneModel?

    private let sceneBuilder: ChiSquareSceneBuilder

    init(sceneBuilder: ChiSquareSceneBuilder = ChiSquareSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        a = snapshot.chiSquareA
        b = snapshot.chiSquareB
        c = snapshot.chiSquareC
        d = snapshot.chiSquareD
        useYates = snapshot.chiSquareUseYates
    }

    func apply(_ result: ChiSquareResult) {
        scene = sceneBuilder.build(from: result)
    }

    func handle(_ action: ChiSquarePageAction) {
        switch action {
        case .run:
            return
        case .reset:
            a = ""
            b = ""
            c = ""
            d = ""
            useYates = false
            scene = nil
        }
    }

    func reset() {
        handle(.reset)
    }

    func validatedInputs() throws -> (Int, Int, Int, Int) {
        (
            try validatedCount(a, label: "A"),
            try validatedCount(b, label: "B"),
            try validatedCount(c, label: "C"),
            try validatedCount(d, label: "D")
        )
    }

    private func validatedCount(_ text: String, label: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw NSError(
                domain: "WordZMac.ChiSquare",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(label) 必须是大于等于 0 的整数。"]
            )
        }
        return value
    }
}
