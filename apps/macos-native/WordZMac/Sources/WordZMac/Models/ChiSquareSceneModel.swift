import Foundation

enum ChiSquareConclusionTone: Equatable {
    case strongEvidence
    case evidence
    case noEvidence
}

struct ChiSquareMetricSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct ChiSquareDetailSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct ChiSquareMatrixSceneRow: Identifiable, Equatable {
    let id: String
    let label: String
    let values: [String]
}

struct ChiSquareSceneModel: Equatable {
    let tone: ChiSquareConclusionTone
    let summary: String
    let summaryDetail: String
    let methodLabel: String
    let effectSummary: String
    let metrics: [ChiSquareMetricSceneItem]
    let observedRows: [ChiSquareMatrixSceneRow]
    let expectedRows: [ChiSquareMatrixSceneRow]
    let rowTotals: [ChiSquareDetailSceneItem]
    let columnTotals: [ChiSquareDetailSceneItem]
    let warnings: [String]
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]
}
