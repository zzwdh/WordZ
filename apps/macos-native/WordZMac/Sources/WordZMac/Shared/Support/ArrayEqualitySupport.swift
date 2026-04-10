import Foundation

extension Array where Element: Equatable {
    func sharesStorage(with other: [Element]) -> Bool {
        guard count == other.count else { return false }
        guard !isEmpty else { return true }
        return withUnsafeBufferPointer { lhs in
            other.withUnsafeBufferPointer { rhs in
                lhs.baseAddress == rhs.baseAddress
            }
        }
    }

    func isContentEqual(to other: [Element]) -> Bool {
        guard count == other.count else { return false }
        if sharesStorage(with: other) {
            return true
        }
        return self == other
    }
}
