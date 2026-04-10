import Foundation

struct TopicTextSlice {
    let id: String
    let paragraphIndex: Int
    let text: String
    let tokens: [String]
}

struct ClusterState {
    var memberIndices: [Int]
    var centroid: [Double]
}
