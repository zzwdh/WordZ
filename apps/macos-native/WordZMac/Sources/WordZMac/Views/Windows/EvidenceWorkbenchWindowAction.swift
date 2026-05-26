import Foundation

enum EvidenceWorkbenchWindowAction {
    case updateReviewStatus(itemID: String, status: EvidenceReviewStatus)
    case exportMarkdown
    case saveDetails
    case deleteItem(itemID: String)
    case copyCitation(itemID: String)
}
