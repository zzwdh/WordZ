import AppKit
import Foundation

@MainActor
package protocol WindowDocumentAttaching: AnyObject {
    func attach(window: NSWindow?)
}

@MainActor
package protocol WindowDocumentSyncing: AnyObject {
    func sync(displayName: String, representedPath: String, edited: Bool)
}
