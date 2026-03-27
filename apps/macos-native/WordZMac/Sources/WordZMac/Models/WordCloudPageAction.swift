import Foundation

enum WordCloudPageAction {
    case run
    case changeLimit(Int)
    case toggleColumn(WordCloudColumnKey)
}
