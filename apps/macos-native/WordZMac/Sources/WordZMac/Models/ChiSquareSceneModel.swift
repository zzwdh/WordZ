import Foundation

struct ChiSquareMetricSceneItem: Identifiable, Equatable {
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
    let summary: String
    let metrics: [ChiSquareMetricSceneItem]
    let observedRows: [ChiSquareMatrixSceneRow]
    let expectedRows: [ChiSquareMatrixSceneRow]
    let warnings: [String]
}
